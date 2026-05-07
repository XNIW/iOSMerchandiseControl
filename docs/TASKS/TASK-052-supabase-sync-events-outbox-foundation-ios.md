# TASK-052: Supabase `sync_events` / `record_sync_event` / outbox — **foundation audit & roadmap iOS** *(planning documentale completato; **BLOCKED / superseded by TASK-053** — nessuna implementazione tecnica)*

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-052
- **Titolo**: Supabase sync_events / record_sync_event / outbox foundation audit iOS — gap analysis vs Android/Supabase, roadmap a slice; superseded by TASK-053 (zero runtime)
- **File task**: `docs/TASKS/TASK-052-supabase-sync-events-outbox-foundation-ios.md`
- **Stato**: BLOCKED
- **Fase attuale**: N/A *(non attiva — superseded by TASK-053)*
- **Responsabile attuale**: N/A *(tracking archiviato; task attivo corrente = TASK-053)*
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(Riallineamento lifecycle post-review TASK-053: TASK-052 non attiva, non DONE, superseded by TASK-053 Slice A.)*
- **Ultimo agente che ha operato**: Codex / Fixer

### Nota lifecycle
TASK-052 ha completato il planning documentale e non richiede execution tecnica propria. Per evitare task ACTIVE concorrenti, l'esecuzione tecnica Slice A e' tracciata solo da **TASK-053**. TASK-052 resta **non DONE** e **non attiva**.

## Dipendenze
- **Dipende da**:
  - **TASK-051** — DONE / Chiusura; ultimo anello ProductPrice push live manuale (`inventory_product_prices`), **senza** `sync_events` / outbox.
  - Catena **TASK-048 → 049 → 050 → 051** — preview read-only, apply locale, dry-run push, push live manuale controllato prezzi.
  - **TASK-038** — auth; **TASK-040/043/044** — bridge `remoteID`, baseline/fingerprint, push catalogo manuale *(contesto identità e gating).*
- **Sblocca** *(solo dopo completamento pianificato + future execution esplicita)*:
  - Slice future **A–G** sotto; nessuna attivazione automatica di sync, realtime o background.

## Scopo
Definire, **solo a livello di documento operativo**, la foundation iOS per **`sync_events`** (lettura), **`record_sync_event`** (contratto RPC lato client futuro) e **outbox locale**, allineata semanticamente ad **Android + Supabase** documentati nel progetto, **senza** introdurre sync automatico, write remota o outbox attivo. Il **perimetro “solo PLANNING”** resta lo **storico vincolo** (mai codice in quella fase). **Planning: completato.** TASK-052 e' ora **BLOCKED / superseded by TASK-053** per il lifecycle operativo; **nessun** codice Swift, servizio, DTO o UI e' stato implementato in TASK-052.

## Contesto
- iOS ha coperto progressivamente pull/apply, baseline, push manuale catalogo e pipeline ProductPrice fino al push live controllato (**TASK-051**), sempre con divieto esplicito di **`sync_events`**, **`record_sync_event`** e **outbox**.
- **Android** (repo separato / piano Android; **nessun file Kotlin in questo turno**) ha una lane più matura: eventi operativi, decoder RPC (**TASK-065**), retry outbox head-of-line (**TASK-070**), classificazione mismatch **`p_changed_count` > 1000** vs payload compatti (**TASK-071** → follow-up backend **TASK-072** consigliato). **TASK-068** resta **PARTIAL** (bulk product push / no-op gate live).
- **Supabase**: schema e migrazioni sono attese nel clone **`MerchandiseControlSupabase`** (path tipico `supabase/migrations/`); lo **stato live remoto** non va assunto senza verifica esplicita. Riferimento incrociato: **TASK-040** § schema `sync_events` / RPC `record_sync_event`; **`docs/SUPABASE/TASK-033-schema-audit.md`**.

## Non incluso *(perimetro TASK-052 — vincolo assoluto nel turno corrente)*
- Nessuna **patch Swift** di runtime (nessun `.swift`, `project.pbxproj`, test target execution).
- Nessuna **write Supabase** (insert/update/upsert/delete/RPC live da app).
- Nessuna chiamata **`record_sync_event` live**.
- Nessuna **migration SQL**, RLS, grant, RPC o modifica backend.
- Nessun **outbox attivo** (nessun job, nessun flush automatico).
- Nessun **Realtime**, **background sync**, **sync all’avvio**.
- Nessun cleanup outbox/schema lato Android o Supabase effettuato da questo task.
- Nessuna modifica **Android**.
- Nessun uso di **`service_role`** / chiavi elevate.
- Nessuna **execution** automatica dei test elencati in §10 *(solo pianificazione)*.

## Scope lock documentale

| Area | Consentito in TASK-052 | Vietato in TASK-052 |
|------|------------------------|---------------------|
| Documento task | Chiarire rischi, checklist, roadmap, handoff | Spuntare chiusura o dichiarare DONE |
| MASTER-PLAN | Allineare stato **ACTIVE**, fase task e tracking responsabile | Dichiarare execution **tecnica** completata o DONE senza evidenza |
| Codice iOS | Nessuna modifica | `.swift`, `.xcodeproj`, test target, build settings |
| Supabase | Solo lettura documentale locale se necessaria | SQL live, RPC live, migration, RLS, grant, publication |
| Android | Solo riferimento documentale | Patch Kotlin, Gradle, Room, outbox Android |
| UI/UX | Solo decisioni future e linee guida | Implementazione `OptionsView` o nuove schermate |

## File potenzialmente coinvolti *(lettura futura in EXECUTION — non modificati in PLANNING)*
**iOS (repo `iOSMerchandiseControl`):**
- `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-048-supabase-productprice-foundation-ios.md` … `TASK-051-*.md`
- `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md` *(schema `sync_events` / RPC riassunti)*
- `docs/SUPABASE/TASK-033-schema-audit.md`
- Servizi: `SupabaseClientProvider.swift`, `SupabaseInventoryService.swift`, `SupabaseInventoryDTOs.swift`, `SupabaseCatalogBaselineReader.swift` / `Writer.swift`, `SupabaseManualPushService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseProductPricePreviewService.swift`, `OptionsView.swift` *(DEBUG Supabase)*
- Modelli SwiftData: `Models.swift` (`remoteID`, relazioni)

**Android** *(solo riferimento funzionale esterno — path tipici nel piano Android, non eseguiti qui)*:
- Task documentali: **TASK-045 / 046 / 061 / 063 / 065 / 068 / 070 / 071** *(numerazione piano Android; verificare file task nel repo Android)*
- Componenti attesi: `InventoryRepository`, modelli sync event, `SupabaseSyncEventRemoteDataSource`, logica outbox *(contratto comportamentale, non copia-incolla).*

**Supabase locale** *(clone `MerchandiseControlSupabase`)*:
- Migrazione(i) **`sync_events`** *(es. prefisso documentato in TASK-040: `20260424021936_task045_*` — verificare su clone aggiornato)*
- RPC **`public.record_sync_event(...)`** — firma, validazione `p_changed_count`, limiti `entity_ids` / `metadata`
- **RLS**, **GRANT** `authenticated`, eventuale **publication realtime**

---

## Gap analysis iOS vs Android / Supabase

### Cosa iOS ha già
| Area | Stato sintetico |
|------|-----------------|
| Auth session-aware | **TASK-038** — `SupabaseAuthService` / `SupabaseAuthViewModel`, gate account |
| Baseline / fingerprint | **TASK-043** — `SupabaseCatalogBaselineReader` / `Writer`, preflight integrato |
| Bridge `remoteID` | **TASK-040** — Product / Supplier / Category |
| Pull / preview / apply locale catalogo | **TASK-034–040, 039** — read-only → apply controllato |
| Push manuale catalogo | **TASK-044** — supplier/category/products, read-back, baseline-gated |
| ProductPrice | **TASK-048–051** — preview, apply locale insert-only, dry-run, push live manuale `inventory_product_prices` |
| UI DEBUG Supabase | **`OptionsView`** — diagnostica, dry-run, push controllati *(pattern riusabile per future slice diagnostiche)* |

### Cosa manca *(foundation sync event / outbox)*
| Componente | Nota |
|------------|------|
| Reader **`sync_events`** | DTO decode, paginazione/watermark, filtri per `owner_user_id` / dominio |
| Client **`record_sync_event`** | Serializzazione payload, gestione errori RPC, allineamento vincoli SQL |
| **Outbox** SwiftData | Modello persistente code-first, stati, idempotenza chiave, **non** flush in PLANNING |
| **Watermark** monotono | Ultimo evento / cursore sicuro vs gap e replay |
| **Fallback full sync** | Se incrementale inaffidabile o mismatch session — requisito da definire nelle slice di execution |
| **Retry** | Head-of-line blocking (**TASK-070** Android) — design solo |
| **Realtime** / **Background** | Fuori da TASK-052 operative; slice G futura |

### Matrice permessi operativi per future slice
| Slice | Read Supabase | Write Supabase | SwiftData write | UI visibile utente | Note |
|-------|---------------|----------------|-----------------|--------------------|------|
| A | Sì, solo `select` read-only se autorizzato | No | No, salvo test fixture in memoria | No | DTO/service read-only + test decode |
| B | Sì, read-only | No | Solo watermark volatile o stato diagnostico non persistente | Sì, solo sezione DEBUG in `OptionsView` | UI nativa, discreta, collassabile |
| C | No obbligatorio | No | Solo se il task futuro autorizza stub outbox persistente | No o DEBUG | Processor disattivato |
| D | No live | No | No | No | Contract test con mock/fake |
| E+ | Da definire | Solo con override esplicito | Da definire | Da definire | Fuori perimetro TASK-052 |

### Rischi espliciti *(documentati — mitigazione in slice future)*
| Rischio | Dettaglio |
|---------|-----------|
| **TASK-071** | Backend `record_sync_event`: **`p_changed_count` ammesso 0…1000** nel SQL locale; Android può inviare eventi **compatti** con `entity_ids` vuoto e `changed_count` reale **> 1000** → rifiuto RPC. Mitigazione backend: **TASK-072** (follow-up consigliato). iOS deve **pre-validare** o spezzare eventi *prima* di EXECUTION live. |
| **Drift schema live vs clone** | Migrazioni Supabase locale non garantiscono parity produzione senza audit esplicito. |
| **TASK-068 PARTIAL** | Bulk product push / no-op gate su Android non completi — non assumere parità di semantica “massiva” su iOS senza re-read del piano Android. |
| **RPC assente o diversa in prod** | Verificare esistenza e firma **`record_sync_event`** sul progetto Supabase **effettivamente** usato dall’app prima di qualsiasi write. |
| **Decoder JSON** | RPC/restituzioni possono essere **object vs array** e campi extra — allineare a fix **TASK-065** Android in design DTO iOS. |

### Checklist schema/RPC da completare prima di qualsiasi EXECUTION
Questa checklist serve a evitare che una futura Slice A parta assumendo dettagli non verificati. Va compilata leggendo **repo iOS aggiornata**, **repo Supabase locale** e, solo se autorizzato, un audit live **read-only**.

| Area | Da verificare | Regola TASK-052 |
|------|---------------|-----------------|
| Tabella `sync_events` | colonne reali, tipi, indici, ordinamento stabile, eventuale dominio/entity/action | Non inferire nomi colonna dal codice Android senza riscontro schema |
| RPC `record_sync_event` | firma completa, tipo ritorno, shape risposta object/array, campi extra, limiti payload | iOS deve decodificare in modo tollerante come Android TASK-065 |
| `p_changed_count` | limite effettivo locale/live e messaggio errore su overflow | Nessun evento reale iOS finché il limite non è gestito lato client o backend |
| `entity_ids` / metadata | formato atteso, dimensione massima, compatibilità eventi compatti | Evitare payload massivi non paginati |
| RLS / owner | policy owner-scoped, grants `authenticated`, impossibilità cross-user | Nessun uso di chiavi elevate |
| Realtime publication | presenza tabella in publication, payload disponibile | Solo informativo in TASK-052; non abilita subscribe |
| Stato live | se e quando verificato, data, metodo e risultato | Locale ≠ live finché non documentato |

### Definition of Ready per futura Slice A
Una futura **Slice A** può passare a EXECUTION solo quando queste condizioni sono vere o esplicitamente marcate come non verificabili nel contesto locale:

- [ ] Repo iOS aggiornata letta prima di modificare file.
- [ ] Schema locale Supabase `sync_events` / `record_sync_event` letto e citato nel file task o nel handoff.
- [ ] Stato live remoto non assunto: se non verificato, resta marcato come **UNKNOWN**.
- [ ] Firma RPC e shape risposta documentate prima di scrivere DTO.
- [ ] Limite `p_changed_count` documentato e trasformato in guard client o blocco esplicito.
- [ ] Nessuna write prevista nella Slice A: solo DTO, service read-only e test decode/fake.
- [ ] Grep/check no-write definito prima della review della slice.
- [ ] Una sola slice scelta: vietato mescolare A+B+C nello stesso task senza nuovo override utente.

---

## Roadmap a slice *(ordine logico; EXECUTION solo dopo override utente esplicito per slice)*

| Slice | Descrizione | Write remota / outbox attivo |
|-------|-------------|------------------------------|
| **A** | Audit schema + **DTO iOS read-only** `sync_events` (tipi, `Decodable`, tolleranza campi extra); **nessuna write** | No |
| **B** | **Preview diagnostica** (DEBUG): ultimi N eventi, watermark locale volatile o sola lettura UI; **nessuna mutazione** dati cloud | No |
| **C** | **Design** modello SwiftData outbox (entità, stati, retention); **persistenza opzionale stub** solo se task futuro lo definisce; **non attivare** processor | No |
| **D** | **`record_sync_event`**: test **dry-run / contract** con **mock** (payload valido/invalido, `changed_count` boundary, `entity_ids` shape); **nessuna** chiamata live | No |
| **E** *(futura)* | Push eventi **reali** manualmente controllato (analogia TASK-044/051) | Solo con gate espliciti |
| **F** *(futura)* | Realtime / manual refresh subscribe `sync_events` | No auto-sync implicito |
| **G** *(futura)* | Background sync / scheduling *(molto conservativo)* | Solo dopo policy privacy/battery |

### Decisioni UI/UX per eventuale Slice B DEBUG
Se una futura execution autorizza una preview diagnostica in `OptionsView`, scegliere automaticamente l’opzione più coerente con lo stile iOS esistente:

- Usare una sezione **DEBUG Supabase** collassabile o chiaramente separata, non una schermata principale nuova.
- Preferire componenti SwiftUI nativi: `Form`, `Section`, `List`, `DisclosureGroup`, `ProgressView`, `Label`, `Button(role:)`, `confirmationDialog` solo dove serve.
- Mostrare stato sintetico prima dei dettagli: ultimo evento letto, eventuale watermark, numero eventi caricati, errore leggibile.
- Nascondere dettagli tecnici lunghi dietro disclosure/copy action; niente tabelle dense se non necessarie.
- Stati obbligatori: vuoto, loading, errore, schema non disponibile, sessione assente, read-only success.
- Nessuna azione distruttiva o write nella UI DEBUG di TASK-052/Slice B.
- Localizzazione futura IT/EN/ES/zh-Hans; se mancano stringhe, documentare placeholder invece di hardcodare in produzione.

### Vincoli di efficienza e robustezza per future letture `sync_events`
Le future slice read-only devono essere progettate per dataset grandi e per non degradare l’esperienza utente:

- Lettura sempre bounded: default suggerito **ultimi 50 eventi**, con limite massimo documentato prima di aumentare.
- Ordinamento deterministico: preferire coppia stabile tipo `created_at` + `id` se disponibile nello schema reale.
- Paginazione/range obbligatoria per qualunque lista oltre il primo blocco.
- Nessuna decodifica di payload enormi in UI principale; dettagli lunghi solo on-demand/collassabili.
- Errori RPC/PostgREST convertiti in messaggi brevi e copiabili, senza stack trace visibili all’utente normale.
- Logging privacy-safe: non stampare liste massive di barcode, payload completi o token/session data.
- Nessuna lettura automatica ripetuta in loop; refresh manuale o trigger controllato finché realtime/background non hanno task dedicati.

---

## Criteri di accettazione *(contratto TASK-052 — lifecycle documentale)*
- [ ] File task **TASK-052** **BLOCKED / superseded by TASK-053** con planning completato *(nessuna implementazione tecnica)*; non task attivo concorrente.
- [ ] **`docs/MASTER-PLAN.md`** aggiornato: progetto **ACTIVE**, task attivo unico **TASK-053**, TASK-052 non attivo e non DONE.
- [ ] Riferimenti **Android** (TASK-045/046/061/063/065/068/070/071) e **Supabase** (migrazioni/RPC/RLS) **espliciti** nel documento *(come indirizzi di lettura, non come assunzione di stato live)*.
- [ ] Rischi **TASK-071** (`p_changed_count`) e **TASK-068 PARTIAL** documentati nella gap analysis.
- [ ] Roadmap **A–G** dichiarata con confini **no-write** / **no-outbox-active** per le slice in-scope del planning.
- [ ] Divieti §**Non incluso** e §**Scope lock documentale** coerenti con il turno *(nessuna execution Swift)*.
- [ ] **Handoff** storico chiaro: execution tecnica separata trasformata in **TASK-053 / Slice A** dopo user override esplicito.
- [ ] Checklist schema/RPC aggiunta e marcata come **da compilare in REVIEW/EXECUTION futura**, non come stato verificato.
- [ ] Matrice permessi operativi A–E+ presente e coerente con il divieto di write in PLANNING.
- [ ] Decisioni UI/UX per futura Slice B DEBUG definite senza obbligare una patch UI immediata.
- [ ] Nessuna assunzione di schema live remoto: ogni riferimento live resta esplicitamente “da verificare”.

## Checklist review del planning
La REVIEW di TASK-052 deve controllare solo qualità del planning, non compilazione o runtime:

- [ ] Il documento separa chiaramente **PLANNING** da **future EXECUTION**.
- [ ] Ogni riferimento Android è usato come contratto funzionale, non come istruzione di porting Kotlin → Swift.
- [ ] Ogni riferimento Supabase distingue locale, live, assunzione e verifica.
- [ ] La roadmap non abilita sync automatico per errore.
- [ ] La futura UX DEBUG non invade il flusso principale dell’app.
- [ ] I rischi TASK-068/TASK-071 restano bloccanti per eventi massivi live.
- [ ] Il handoff finale richiede esplicitamente override utente prima di qualsiasi execution.

## Controllo coerenza MASTER-PLAN

- [ ] Stato globale progetto: **ACTIVE**.
- [ ] Task attivo unico: **TASK-053**.
- [ ] TASK-052: **BLOCKED / superseded by TASK-053**, non DONE, non attivo.
- [ ] Responsabile task attivo: **Cursor / Codex** su TASK-053.
- [ ] Ultimo task completato precedente: **TASK-051 DONE / Chiusura**.
- [ ] Nessuna frase nel MASTER-PLAN indica execution Swift, Supabase write, outbox attivo, realtime o background sync per TASK-052.
- [ ] Prossimo passo: **REVIEW post-fix di TASK-053**, non execution automatica di TASK-052.

---

## 10. Test futuri *(pianificati — NON eseguiti in TASK-052 PLANNING)*

| # | Area | Intento |
|---|------|---------|
| T-52-01 | DTO decode | Coerenza **object/array/extra fields** come **TASK-065** Android |
| T-52-02 | Guard client | Pre-validazione **`changed_count`** vs limite **1000** *(fail-fast lato app se backend non aggiornato)* |
| T-52-03 | Watermark | Monotonicità cursore / rilevazione gap |
| T-52-04 | Fallback | Scenario “full sync obbligatorio” se watermark inconsistente |
| T-52-05 | Security | `owner_user_id` / session mismatch → nessun insert evento |
| T-52-06 | Audit | Grep / test **no-write**: nessuna RPC live nei test di contract |
| T-52-07 | L10n | Stringhe UI DEBUG future **IT / EN / ES / zh-Hans** |
| T-52-08 | No-write guard | Verifica che Slice A/B non chiami insert/update/upsert/delete/RPC live |
| T-52-09 | Pagination | Lettura eventi con limite/range stabile e ordinamento deterministico |
| T-52-10 | Privacy/logging | Log senza barcode massivi, payload completi o dati sensibili non necessari |
| T-52-11 | UI states | Empty/loading/error/session-missing/schema-missing nella futura sezione DEBUG |

---

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | TASK-052 è **solo planning** nel turno di creazione | Execution immediata Slice A | Evitare sync prematuro e scope creep | attiva |
| 2 | Fonte schema primaria = **clone Supabase locale** + audit live esplicito | Assumere prod = locale | Drift rischio TASK-040 / TASK-071 | attiva |
| 3 | Parità Android = **contrattuale**, non copia codice | Porting Kotlin | Perimetro repo iOS | attiva |
| 4 | UI DEBUG futura resta in `OptionsView` salvo evidenza contraria | Nuova tab/schermata principale | Riduce complessità e mantiene feature nascosta a utenti normali | proposta |
| 5 | Ogni futura slice deve avere grep/check no-write dedicato | Fidarsi solo del diff manuale | Evita attivazione accidentale di sync/eventi | proposta |
| 6 | Eventi massivi iOS devono essere spezzati o bloccati se backend mantiene cap 1000 | Invio compatto non validato | Allineamento al rischio TASK-071 | proposta |

## Domande aperte da NON risolvere in PLANNING
Queste domande vanno mantenute come input per future slice, non trasformate in execution implicita:

1. Lo schema live remoto coincide davvero con il clone Supabase locale per `sync_events` e `record_sync_event`?
2. Il backend verrà aggiornato con TASK-072 prima che iOS invii eventi reali?
3. Il watermark iOS deve essere volatile DEBUG-only o persistito in SwiftData in una slice successiva?
4. Gli eventi iOS useranno lo stesso dominio/action naming Android o una mappa compatibile ma separata?
5. La UI DEBUG deve restare sempre nascosta dietro modalità debug o può essere visibile nelle Opzioni in build normale?
6. Qual è il limite massimo sicuro di eventi/payload da visualizzare senza degradare device più vecchi?

---

## Planning (Claude)

### Analisi
Dopo **TASK-051**, iOS ha parità funzionale “dati prezzi” fino al push **manuale** su tabella dedicata, ma **non** partecipa al sistema **telemetria/eventi** che Android usa per coordinare sync e retry. La tabella **`sync_events`** e l’RPC **`record_sync_event`** sono il collante backend; senza reader e senza strategia outbox, iOS non può né osservare né (in futuro) registrare eventi in modo sicuro. Il vincolo **0…1000** su `p_changed_count` (**TASK-071**) è un **blocco reale** per eventi massivi finché il backend non evolve (**TASK-072**). **TASK-068 PARTIAL** ricorda che anche lato Android il bulk/no-op non è chiuso: iOS non deve overshooting verso “bulk event” senza redesign backend.

### Approccio proposto
1. **Planning** — audit documentale (questo file + MASTER-PLAN) come deliverable della fase **PLANNING**: **completato** per contenuto; la fase task è passata a **EXECUTION documentale** solo per consolidamento e handoff verso **REVIEW** *(senza codice)*.
2. In **EXECUTION tecnica** futura (slice per slice, es. **TASK-053 / Slice A**): partire da **A** solo dopo aver compilato la checklist schema/RPC; poi **B** (DEBUG read-only in `OptionsView` se utile), poi **C** (design persistenza outbox disattivata), poi **D** (mock contract). Non abilitare processor, realtime, background o write eventi fino a task dedicati **E–G** e override utente.
3. Ogni slice futura richiede **grep anti-scope** coerente con TASK-041/044/051 (`record_sync_event`, `outbox`, write), più una verifica esplicita che non siano stati introdotti loop automatici, subscribe realtime o background task fuori perimetro.

### File da modificare *(futura EXECUTION — non ora)*
- Nuovi file probabili: `SupabaseSyncEventDTOs.swift`, `SupabaseSyncEventPreviewService.swift` (nomi indicativi)
- Estensioni: `SupabaseInventoryService.swift` per select `sync_events`
- UI: `OptionsView.swift` (solo se slice B autorizzata)
- Test: `iOSMerchandiseControlTests/*SyncEvent*`
- Check documentali/grep futuri: confermare assenza di `record_sync_event` live, `insert`/`upsert` su `sync_events`, processor outbox e subscribe realtime fuori slice.

### Rischi identificati
- **Mismatch TASK-071** — mitigare con guard client + allineamento backend prima di push eventi reali.
- **Schema drift** — confronto clone vs ambiente target prima di write.
- **Scope creep** — realtime/background richiedono task separati (**F/G**).

### Handoff *(post-EXECUTION documentale — questo turno)*

**ARCHIVIATO / SUPERSEDED BY TASK-053** — Documento consolidato (audit, roadmap, divieti, slice **A–G**). **TASK-052 non è DONE** e non e' task attivo.

- **Nessuna execution Swift** e **nessuna execution Supabase** in questo task. **Nessuna Slice A** (né B/C/D) **implementata** qui.
- **Prossima fase**: nessuna fase attiva su TASK-052; il prossimo passo operativo e' **REVIEW post-fix di TASK-053**.
- **Prossimo agente**: **Claude / Reviewer** o **Utente** su TASK-053.
- **Output atteso**: TASK-052 non va promosso a **DONE** senza conferma utente.
- **Dopo TASK-052**: l'eventuale execution tecnica separata e' stata avviata come **TASK-053 / Slice A** (DTO + service read-only + test decode/fake, senza UI e senza write). UI DEBUG eventuale solo in task successiva separata. **Nessun** sync automatico, **`record_sync_event` live**, **outbox attivo**, **realtime** o **background sync** finché non definito in quel task.

**Nota di perfezionamento**: per slice successive a **TASK-053**, completare o marcare “non verificabile in locale” la checklist schema/RPC, poi **una sola slice**. Per dubbi UX futuri: sezione DEBUG in `OptionsView`, read-only, collassabile, stati chiari, senza azioni cloud mutanti.

---

## Execution (Cursor)

### Obiettivo compreso
Transizione **documentale** **PLANNING → EXECUTION** per consentire **REVIEW operativa** del solo materiale di pianificazione; **zero** implementazione runtime.

### Tipo execution
**Documentazione only.** Nessuna patch runtime.

### Azioni eseguite
- Promossa la task da **PLANNING** a **EXECUTION** per consentire review operativa del documento.
- Consolidato il perimetro: TASK-052 resta **audit/roadmap** `sync_events` / `record_sync_event` / outbox.
- Confermati i divieti: nessun file Swift, nessuna write Supabase, nessun outbox attivo, nessun realtime/background sync.
- Confermato che la futura implementazione tecnica dovrà essere **task separato**, consigliato **TASK-053 / Slice A**.

### Azioni non eseguite
- Nessuna implementazione DTO.
- Nessun service read-only.
- Nessun test.
- Nessuna UI DEBUG.
- Nessuna chiamata live Supabase.
- Nessun uso di `record_sync_event`.

### Esito
**SUPERSEDED BY TASK-053 / non DONE.**

### Handoff → Review
- **Prossima fase**: nessuna fase attiva su TASK-052
- **Prossimo agente**: Claude / Reviewer o Utente su **TASK-053**
- **Azione consigliata**: review post-fix di **TASK-053**; **non** dichiarare TASK-052 **DONE** senza conferma utente.

---

## Review (Claude)
*(Da compilare dopo **REVIEW** del documento — planning archiviato; EXECUTION corrente solo documentale.)*

---

## Fix (Codex)
*(N/A finché non esiste REVIEW con CHANGES_REQUIRED.)*

---

## Chiusura
- [ ] Utente ha confermato il completamento *(DOPO REVIEW e eventuali cicli — TASK-052 **non è DONE** finché non confermato esplicitamente dall’utente)*

### Follow-up candidate
- **TASK-072** (backend) — allineamento `p_changed_count` / eventi compatti Android (**TASK-071**).

### Data completamento
*(TBD)*
