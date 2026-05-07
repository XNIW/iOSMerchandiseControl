# TASK-054: Supabase `sync_events` Slice B iOS — UI DEBUG read-only in `OptionsView`

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-054
- **Titolo**: Supabase sync_events Slice B iOS — UI DEBUG read-only in OptionsView
- **File task**: `docs/TASKS/TASK-054-supabase-sync-events-debug-ui-readonly-ios.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: Cursor / Planner
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(Creazione planning-only; zero patch Swift questo turno.)*
- **Ultimo agente che ha operato**: Cursor / Planner

### Dipendenze
- **Dipende da**:
  - **TASK-053** — **DONE / Chiusura**. Slice A: DTO `RemoteSyncEventRow` / `SyncEventJSONValue`, `SupabaseSyncEventPreviewService`, `SupabaseSyncEventPreviewFetching`, `SupabaseSyncEventRemoteReader`, default **50** / max **200**, decoder object/array + campi extra, XCTest fake/mock + grep no-write production.
  - **TASK-052** — **BLOCKED / superseded by TASK-053**; **non DONE** e senza execution tecnica propria; solo contesto roadmap/outbox/documentazione.
- **Non dipende da**: TASK-055 *(vietato aprire in questo ciclo)*, Android diretto.

## Scopo
Pianificare una **UI DEBUG Supabase**, **solo lettura**, dentro `OptionsView` (solo build **DEBUG**, coerente con sezioni Supabase esistenti), che invochi esplicitamente `SupabaseSyncEventPreviewService.loadLatestEvents(...)` *(o wrapper equivalente)* per mostrare un **campione compatto** degli ultimi eventi `sync_events` restituiti da PostgREST, **senza** alcuna scrittura cloud, outbox, subscribe Realtime né sync in background.

## Non incluso *(perimetro assoluto — Slice B planning + future execution vincolate)*
- Nessuna **write Supabase** (insert/upsert/update/delete/RPC).
- Nessuna chiamata **`record_sync_event`**.
- Nessun **outbox** locale né processor.
- Nessun **realtime subscribe** (`channel` / `subscribe`).
- Nessun **background sync** / `BGTask`.
- Nessun **polling automatico**, refresh on appear globale o timer.
- Nessun push/sync/upload live oltre a quanto gia' esiste fuori da questo task.
- Nessuna modifica **Android**.
- Nessuna **migration/schema/RLS/RPC/grant/publication** Supabase.
- Nessun uso di **`service_role`** o esposizione di segreti/token JWT/session string in UI o log utente.
- Nessun caricamento/UI di **liste massive** di barcode/UUID nei `entity_ids`; nessuna visualizzazione predefinita di **`metadata` JSON completo**.
- **Questo turno (planning)**: nessuna patch **Swift**, **test**, **`project.pbxproj`**, build, XCTest, chiamata Supabase live.

## Fonti lette *(planning — 2026-05-06)*
- `docs/MASTER-PLAN.md` *(stato IDLE pre-apertura TASK-054, TASK-052 BLOCKED/superseded, TASK-053 DONE)*.
- `docs/TASKS/TASK-052-supabase-sync-events-outbox-foundation-ios.md` *(matrice slice A/B read-only UI DEBUG, rischi TASK-065/068/070/071)*.
- `docs/TASKS/TASK-053-supabase-sync-events-slice-a-readonly-ios.md` *(implementazione Slice A e file toccati)*.
- `iOSMerchandiseControl/OptionsView.swift` *(pattern `#if DEBUG`, `Section` + `SectionHeader`, `DisclosureGroup`, `Label`, `ProgressView`, `Button`, `L(...)`, gated auth `canRunAuthenticatedSupabaseActions`, reset su logout/cambi account)*.
- `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift` *(campi DTO privacy-relevant: `ownerUserID` — da non enfatizzare oltre pattern esistente; `entity_ids` / `metadata` come JSON ricco)*.
- `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift` *(protocol fetcher, summary `effectiveLimit` / clamp, reader read-only session-gated, mapping errori → `SupabaseInventoryServiceError`)*.
- `iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests.swift` *(Mock actor, fake senza live, test no-write tokens su sorgenti production)*.
- Localizzazioni: chiavi esistenti sotto `options.supabase.*` in `it.lproj`, `en.lproj`, `es.lproj`, `zh-Hans.lproj` / `Localizable.strings`.

## Contesto tecnico sintetico *(da TASK-053)*
- **`SupabaseSyncEventPreviewService`**: entry point logico UI; `loadLatestEvents(limit:)` → `SyncEventPreviewSummary` con `events`, `effectiveLimit` (clamp max **200**, default implicito **50** se `nil`).
- **`SupabaseSyncEventRemoteReader`**: richiede sessione autenticata; errori tipici gia' mappati: `sessionMissing`, `permissionDeniedOrRLS`, `schemaDrift`, `decodingError`, network, ecc.
- **UI Options esistente**: diagnostica/catalog probe, preview pull sheet, ProductPrice preview/apply/manual push — tutte gated e con badge/copy “read-only” / developer; **TASK-054** deve restare **diagnostico**, non prod.

## Riferimento funzionale Android *(solo rischio — NON implementare)*
- **TASK-065**: tolleranza object/array/extra in client — allineamento gia' coperto lato iOS DTO/decoding TASK-053; UI non deve assumere forma JSON di `entity_ids`/`metadata` per UX.
- **TASK-070**: retry outbox head-of-line — fuori scope; nessuna coda UI.
- **TASK-071**: `p_changed_count` > **1000** vs RPC/invariant backend — eventualmente solo copy di cautela futura su eventi molto grandi (**non** calcolo write lato UI).
- **TASK-068 PARTIAL**: cautela su operazioni bulk/massive — UI mostra **solo campione**, conteggi e **changed_count**, non liste complete di entita'.

---

## UX/UI planning *(Slice B — progettazione)*

### Collocazione
- **Build**: solo `#if DEBUG` *(come tutta la fascia Supabase in `OptionsView`)* — Release senza superficie nuova.
- **Posizione consigliata**: nuova **`Section`** compatta **dopo** la Section **baseline** catalogo e **prima** della Section **manual push preflight**, oppure immediatamente **dopo** le card ProductPrice nella prima Section DEBUG — **preferenza**: **Section dedicata** tra baseline e preflight, footer con note privacy/read-only, per separare diagnostics da CTA destructive/push neighboring.

### Componenti SwiftUI *(nativi Apple)*
- `Section` + `SectionHeader` *(pattern esistente `L("options...")`, SF Symbol discreto tipo `calendar.badge.clock` o `clock.arrow.circlepath`)*.
- `DisclosureGroup` per espandere lista eventi.
- Righe sintetiche con `Label`, `LabeledContent` dove utile.
- `ProgressView` durante fetch **solo** mentre task esplicito dell'utente e' attivo.
- `Button` unica/azion primaria tipo **«Carica / Aggiorna eventi sync»** *(testi localizzati; stesso spirito delle altre CTA diagnostica)* — **variante UX**: un solo pulsante che fa da load+refresh (**no** polling).
- Lista eventi: `ForEach` su **`prefix(displayCap)`** in memoria *(vedi § Performance)* — stile compatto `.font(.footnote)` come altre diagnostics.

### Badge e chiarezza ruolo utente developer
- Chip/badge testuale **«Solo lettura»** / «Read-only» coerente con ProductPrice preview/dry-run (colore neutro/arancione come altre diagnostics, **non** blu primario da feature consumer).

### Summary *(sempre visibile sopra lista, anche collassato)*
Mostrare in ordine leggibile:
1. Numero **eventi caricati** nell'ultimo fetch (es. `summary.events.count` ≤ display cap UI).
2. **Ultimo evento** sintetico: `domain` • `event_type` • `changed_count`.
3. **Ultimo `created_at`** dell'evento piu' recente nel campione *(formato `Date.FormatStyle` compatto locale-aware)*.
4. **Messaggio errore localizzato** se ultimo stato = errore *(via mapping `localizedSupabaseDiagnosticMessage` riusabile o helper dedicato **senza** token)*.
5. **Stato sessione**: assenza sessione / account non collegato / auth in transizione *(riusa gate `canRunAuthenticatedSupabaseActions` e messaggi chiave esistenti se possibile)*.
6. **Limite fetch**: mostrare `effectiveLimit` e, se `isLimitClamped`, nota micro *(come da `SyncEventPreviewSummary`)* — **privacy-safe**, no raw query string.

### Dettaglio evento *(solo in `DisclosureGroup` per riga)*
Campi sicuri da mostrare default:
- `domain`
- `event_type`
- `changed_count`
- `source` *(opzionale, stringa corta)*

Campi tecnici disclosure secondaria/sotto-riga:
- `created_at` formattato
- `id` numerico Postgres

Non mostrare:
- **`metadata` completa** *(default)* — eventualmente disclosure terziaria «Conteggio chiavi metadata: N» o preview troncata a **≤ 48 caratteri** senza contenuti sensibili noti *(no password, no bearer)*.
- **`entity_ids` completo** — solo **tipo shape** («oggetto» / «array» / vuoto) e **conteggio elementi stimato** o «presente/non presente». Se indispensabile UX: prima **barcode**/UUID truncato **mai** liste complete.

### Accessibilita'
- Tutte le nuove label via **`L(...)`** + **`accessibilityLabel`/`Hint`** sul pulsante refresh e sul DisclosureGroup («Mostra gli ultimi eventi sincronizzazione caricati», ecc.).
- **Dynamic Type**: usare `.font`/`.foregroundStyle(.secondary)` e linee wrapping; evitare altezza fissa.

### Stati UX *(enum consigliato in execution futura — non implementato ora)*
| Stato | Comportamento |
|-------|----------------|
| `idle` | Nessun fetch ancora eseguito dall'apertura scheda; istruzioni concise. |
| `loading` | `ProgressView` + disabilitazione CTA duplicate / reentrancy guard. |
| `successEmpty` | Zero righe dopo fetch OK *(non errore)*. |
| `successWithEvents` | Summary popolato + lista troncata. |
| `error` | Messaggio localizzato; **retry solo manuale** (stesso pulsante). |
| `noSession` | Allineato a `sessionMissing` / non autenticato — CTA disabilitato o messaggio sessione richiesta. |
| `schemaOrLiveUnknown` | Mappatura da `schemaDrift` / decoding / mismatch — linguaggio neutro («schema o risposta imprevisti»); niente stack trace. |
| `cancelled` | Task `Task`/async cancellato su `onDisappear` o logout — stato torna `idle` o `cancelled` con reset messaggio benigno *(no leaked partial rows se policy = clear on cancel)* |

---

## Architettura proposta *(execution futura)*

### Riuso servizi TASK-053
- Istanziare **`SupabaseSyncEventPreviewService`** con fetcher **`SupabaseSyncEventRemoteReader(clientProvider: ...)`**, stesso **`SupabaseClientProvider`** session-aware gia' usato da altri servizi DEBUG.
- **Nessuna** nuova API network oltre a `loadLatestEvents`.

### Stato/UI layer
- **Opzione A** (preferita se complessita' resta bassa): `@State` + piccola funzione `loadSyncEvents()` in `OptionsView` *(pattern `runSupabaseDiagnostic`)* — minimo churn.
- **Opzione B**: `@Observable`/`ObservableObject` **ViewModel dedicato** read-only *(simmetrico a `SupabasePushPreflightViewModel` ma **senza** side write)* se la logica supera ~80 righe — file dedicato tipo `SupabaseSyncEventDebugLoader.swift` o `SupabaseSyncEventDebugViewModel.swift` (**nome da decidere in execution**).

### Storage e lifecycle
- Stato **volatile** in RAM; **`UserDefaults`/SwiftData/File** vietati per cache eventi/metadata.
- **Reset** su: `onDisappear` della scheda *(opzionale clear — da decidere tra «mantieni ultimo campione» vs «privacy first clear»)*; **`onChange` userID / sign-out** deve almeno **invalidate** liste e tornare idle *(come reset ProductPrice quando cambia utente)*.
- ** Nessuna mutazione** SwiftData/catalogo/prices dall'azione di refresh.

---

## Performance
- **Fetch default**: implicito TASK-053 = **50** eventi tramite API `loadLatestEvents()` senza argomento *(o equivalente documented)* — **TASK-054** non richiede override UI per limite nella prima slice UI.
- **Massimo remotato**: clamp **200** gia' enforcement service — UI **non deve** permettere spinner verso «carica migliaia».
- **Display cap UI**: suggeriti **≤ 20 righe** mostrate anche se `events.count` è 50; documentare nella card footer *«Campione UI: prime N di M caricate»* con N=20 fisso TASK-054 o configurabile codice-comment.
- **Nessuna paginazione** cursore/watermark in TASK-054 — task futuro se si vuole paging.

---

## Privacy / security
- **No token/JWT/session raw** nella card sync events *(il pattern esistente mostra UUID utente nella disclosure auth — TASK-054 **non ripete** UUID owner per ogni row se ridondante; mostrare solo `id` evento BIGINT)*.
- **Log/console**: vietato dump JSON completo; errori tecnici sanitizzati uguale a `localizedSupabaseDiagnosticMessage`.
- **`entity_ids` / `metadata`**: come sopra — conteggio/preview truncation; quando copy-to-clipboard e' previsto *(opzionale, non obligatorio TASK-054)* sanitizzare e limitare lunghezza.
- **Screenshot-safe mindset**: developer screen non deve contenere migliaia di identificatori.

---

## Planning — Analisi
- **`OptionsView`** e' gia' la superficie canonica delle operazioni Supabase diagnostica; TASK-053 ha deliberatamente omesso UI — Slice B chiude gap osservabilita' senza allargare superficie Release.
- L' errore/session path e' omogeneo a `SupabaseInventoryServiceError` — riuso localization riduce churn.
- Rischio **drift locale vs prod**: UI deve verbalizzare che la lista riflette solo **attempt read** autenticato, senza garantire equivalenza prod.

---

## Planning — Approccio *(execution futura, ordine suggerito)*
1. **Fake-first VM o state** — costruibile con `MockSyncEventPreviewFetching` estratto o replica test-only friendship *(valutare package visibility in execution)* per UI preview interna prima del reader reale — **solo se** velocizza review; alternative: stato stub in SwiftUI previews non obbligatori TASK-054.
2. **UI scaffolding** OPTIONS read-only dietro `#if DEBUG` con stati sintetici.
3. Wire a **reader reale** + service TASK-053.
4. **`Localizable.strings`** IT / EN / ES / zh-Hans — nuovi key `options.supabase.syncEvents.*` raggruppati.
5. **XCTest**: preferire test su ViewModel/state **puro MainActor/isolato deterministically** dove possibile; snapshot UI solo se progetto usa gia' pattern *(non presumere)* — minimo estratto logico testabile senza Simulator graphics.
6. **Grep anti-write** inclusione eventuali nuovi `.swift` toccati.
7. **Handoff REVIEW Claude** dopo build/test documentati dall'executor.

---

## Planning — File coinvolti *(futura EXECUTION — elenco non esaustivo)*
- `iOSMerchandiseControl/OptionsView.swift` *(integrazione `#if DEBUG`)* — **solo dopo override utente EXECUTION**.
- Eventuale **`SupabaseSyncEventDebug*.swift`** ViewModel/state holder.
- `iOSMerchandiseControl/it.lproj/Localizable.strings`, `en.lproj`, `es.lproj`, `zh-Hans.lproj`.
- Possibile tocco minimo **`iOSMerchandiseControlApp.swift`** / factory provider se DI richiede injector reader — **solo se inevitabile e documentato**.
- **Non** modificare TASK-052/053 archive salvo correzioni puntuali referencing.

---

## Planning — Rischi
| Rischio | Mitigazione planning |
|---------|---------------------|
| Accidental complexity / «feature creep» UI | DisclosureGroup + footer esplicito «solo sviluppatori». |
| Scroll infinito con 50+ JSON pretty-print | CAP UI rows + summary only. |
| Privacy leak barcode | No liste `entity_ids` inline. |
| Reentrancy doppio tap | Guard boolean + disable button during load *(pattern esistenti)* |
| Divergenza Android bulk semantics **TASK-068** | Disclaimer testuale leggerezza campione |

---

## Planning — Test futuri *(pianificati — non implementati in questo turno)*
*(Executor futuro documenta comando/evidenza nella sezione Execution.)*

| Codice | Descrizione | Tipo check |
|--------|-------------|-----------|
| T54-01 | idle → loading → success (eventi vuoti vs con dati fake) | STATIC / UNIT |
| T54-02 | empty dataset remoto (**0 righe**) = success dichiarativo | STATIC / UNIT |
| T54-03 | errore `.sessionMapped` locale / no session gate | STATIC / UNIT |
| T54-04 | errore decoding / schema drift sintetizzato mapper | STATIC / UNIT |
| T54-05 | cancellation su leave view / logout reset state | STATIC / MANUAL |
| T54-06 | Fake fetcher produce 1 evento summary fields | STATIC / UNIT |
| T54-07 | Fake molteplici righe ma UI prefix **≤20** | STATIC / Snapshot code review |
| T54-08 | Clamp display + `effectiveLimit` mostrati coerenti con `SyncEventPreviewSummary.isLimitClamped` | STATIC / UNIT |
| T54-09 | Nessuna string mutation CTA («Push/Sync/Carica su cloud» misleading) fuori glossary esistenti | STATIC / grep strings |
| T54-10 | Localizzazioni IT/EN/ES/zh-Hans `plutil` / duplicate key scan | BUILD/STATIC |
| T54-11 | Grep no-write esteso ai nuovi sorgenti | STATIC |
| T54-12 | Accessibilità: pulsante leggibile VoiceOver (**base**) | MANUAL |
| T54-13 | **OptionsView** non introduce CTA mutate catalogo/sync automatico | STATIC code review |

---

## Criteri di accettazione *(contratto TASK-054 — PLANNING slice)*
1. Planning completo nel file task: Scopo / Non incluso / UX UI / Architettura / Performance / Privacy / Test futuri / CA / roadmap / handoff.
2. **`docs/TASKS/TASK-054-supabase-sync-events-debug-ui-readonly-ios.md`** creato *(questo file)*.
3. **`docs/MASTER-PLAN.md`** aggiornato: stato progetto **ACTIVE**, task attivo **TASK-054**, fase **PLANNING**, responsabile Planner, TASK-052 invariato **BLOCKED/superseded**, TASK-053 **ultimo DONE**.
4. Nessuna patch Swift, test, build, XCTest Supabase/live in questo planning turn.
5. Handoff pianificato verso **REVIEW approvazione planning** prima di qualsiasi EXECUTION Swift.
6. **TASK-054 NON DONE** dopo questo turno.
7. **TASK-055** non aperto / non modificato.

---

## Execution *(Codex)*
*(Vuoto — EXECUTION solo dopo override utente e handoff PLANNING REVIEW-approved.)*

## Fix *(Codex)*
*(Vuoto.)*

---

## Review *(Claude)*
*(Vuoto — prossimo passo: review approvazione planning.)*

---

## Decisioni
- **DEC-054-01**: DIAG UI **solo DEBUG build** — nessuna regressione Release binary surface.
- **DEC-054-02**: Nessun refresh automatico; **solo** azione utente sul pulsante.
- **DEC-054-03**: Nessun contenuto lista `metadata`/`entity_ids` nella prima versione oltre a conteggi / shape / preview troncature.

---

## Roadmap EXECUTION futura consigliata *(post-approval)*
1. **Step 1**: Fake-first state/ViewModel + modello stato enum testabile *(no UI Options ancora)*.
2. **Step 2**: UI `OptionsView` read-only usando fake/in-memory.
3. **Step 3**: Collegare `SupabaseSyncEventRemoteReader` + `SupabaseSyncEventPreviewService` produzione TASK-053.
4. **Step 4**: Localizzazioni IT/EN/ES/zh-Hans complete.
5. **Step 5**: XCTest mirati ViewModel/state + fixture JSON minimi sintetici.
6. **Step 6**: `xcodebuild` build/test + grep no-write + regressioni leggere TASK-048/049/053 come cluster Supabase disponibile nell'execution handoff TASK-054.
7. **Step 7**: REVIEW Claude tecnica UX/scope prima DONE utente.

---

## Handoff (post-planning)
**READY FOR REVIEW APPROVAL — TASK-054 Slice B (planning)**

- **Stato TASK-054**: ACTIVE / PLANNING — **solo documentazione questo turno**.
- **Prossima fase consigliata**: **REVIEW** del planning (Claude reviewer umano/agent perimetro progetto).
- **Prossimo agente dopo approval**: EXECUTION (**Codex / Executor**) **solo su user override esplicito**.
- **Vietato in questo turno**: patch Swift incluso **`OptionsView.swift`**, test, Supabase runtime, dichiarazioni DONE TASK-054.
- Nessuna EXECUTION Swift in questo turno.

---

## Rischi rimasti *(post-planning documentale)*
- Approvazione utente/recensione planning potrebbe richiedere spostamento sezione UX (traffic nella prima DEBUG Section vs Section dedicata) — aggiornare planning senza EXECUTION rogue.
- Se execution sceglie ViewModel separated file, aggiornare `project.pbxproj` *(permesso solo in EXECUTION, non questo turno)*.
