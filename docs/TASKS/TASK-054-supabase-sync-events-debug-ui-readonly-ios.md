# TASK-054: Supabase `sync_events` Slice B iOS — UI DEBUG read-only in `OptionsView`

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-054
- **Titolo**: Supabase sync_events Slice B iOS — UI DEBUG read-only in OptionsView
- **File task**: `docs/TASKS/TASK-054-supabase-sync-events-debug-ui-readonly-ios.md`
- **Stato**: DONE
- **Fase attuale**: DONE / Chiusura
- **Responsabile attuale**: Nessuno / Chiusura
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(Review tecnica + fix mirati completati da Codex su user override; build/test/lint/grep/diff hygiene PASS; **TASK-054 DONE / Chiusura**.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

### Dipendenze
- **Dipende da**:
  - **TASK-053** — **DONE / Chiusura**. Slice A: DTO `RemoteSyncEventRow` / `SyncEventJSONValue`, `SupabaseSyncEventPreviewService`, `SupabaseSyncEventPreviewFetching`, `SupabaseSyncEventRemoteReader`, default **50** / max **200**, decoder object/array + campi extra, XCTest fake/mock + grep no-write production.
  - **TASK-052** — **BLOCKED / superseded by TASK-053**; **non DONE** e senza execution tecnica propria; solo contesto roadmap/outbox/documentazione.
- **Non dipende da**: TASK-055 *(vietato aprire in questo ciclo)*, Android diretto.

## Scopo
Pianificare una **UI DEBUG Supabase**, **solo lettura**, dentro `OptionsView` (solo `#if DEBUG`), che un **ViewModel dedicato read-only** alimenti con **`SupabaseSyncEventPreviewService.loadLatestEvents()` senza argomento** *(default remotato **50**)* — nessuna duplicazione query PostgREST — per mostrare un **massimo di 20 righe** nella lista UI su un campione che puo' contenere fino a **50** eventi caricati — **senza** scrittura cloud, outbox, Realtime, background né polling.

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
- Nessuna **copy-to-clipboard** su payload/errori tecnici TASK-054; **nessun** `print`/dump console di `metadata` / `entity_ids` / righe grezze JSON.
- **TASK-055**: non creare/aprire in questo ciclo (`Non dipende da` sopra rinforzato in planning).
- **Questo turno / ogni turno PLANNING**: nessuna patch **Swift**, **test**, **`project.pbxproj`**, **build**, **XCTest**, chiamata **Supabase live**; **TASK-054 NON DONE**.

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

## UX/UI planning *(Slice B — specifica definitiva pre-EXECUTION)*

### Collocazione definitiva *(DEC-054-05)*
- **Build:** contenuto solo in **`#if DEBUG`** *(coerenza con fascia Supabase esistente; Release senza superficie nuova)*.
- **Ordine Sections `OptionsView`:** nuova **Section dedicata** **subito DOPO** la Section baseline Supabase/catalogo (**`Section` baseline / `baselineStatusRow`** e metriche correlate) **e PRIMA** della Section **push preflight / manual push / collision**.
- **Flusso concettuale UX:** baseline **locale/fingerprint** → **osservabilita' remota** (`sync_events` read-only) → **preflight/push**.
- **Vietato:** inserire la Section sync events dentro la **prima** Section auth/login/diagnostica/prezzi *(evita mix login + ProductPrice + eventi telemetry)*.

### Gate dedicate — Sync Events DEBUG (**DEC-054-12**)
La UI **`sync_events`** **non** deve riusare in modo acritico **`canRunAuthenticatedSupabaseActions`** (o alias equivalenti) se quel gate nel codice aggrega anche prerequisiti **non necessari** a Slice B — es. disponibilità di **preview pull**, **inventory diagnostics**, **ProductPrice preview/apply** o **manual push**.

**EXECUTION pianificata:** introdurre un gate **dedicato** — es. calcolo suggerito **`canRunSyncEventsDebugActions`** — che dipenda **solo** da:
1. **`#if DEBUG`** (build DEBUG / sezione gated come le altre superfici Supabase DIAG);
2. **Utente autenticato / sessione valida** *(se manca sessione → stato ViewModel **`noSession`**, messaggio dedicato; **non** spegnere implicitamente perché altri reader push/pull non sono configurati)*;
3. **`supabaseSyncEventPreviewService != nil`** *(se `nil` → stato **`notConfigured`** — diverso da assenza auth)*;
4. **ViewModel non in stato `loading`** *(CTA/sync events interactions coerenti con **T54-U15**)*;
5. *(Opzionale ma consigliato se gia’ pattern in OPTIONS)* stato auth **non in transizione** *(es. signing-in / teardown intermedio — evita tap durante glitch sessione)*.

**Regola UX:** non disabilitare l’area **sync events** soltanto perché **altri** servizi DEBUG Supabase **`#if DEBUG`** non sono stati injectati/configurati: la disponibilità di questa sezione deve rispecchiare **`canRunSyncEventsDebugActions`** + stati **`notConfigured`**/**`noSession`** del ViewModel, non la matrice dei servizi “manual push” o ProductPrice.

### Section header *(pattern esistenti `SectionHeader` + `L(...)`)*
- **SF Symbol consigliato:** `clock.arrow.circlepath` *(fallback accettabile: `calendar.badge.clock`)*.
- **Titolo** *(localizzare in execution; copy guida):* IT **«Eventi sync recenti»** · EN **«Recent sync events»** · ES / zh-Hans versioni equivalenti nelle `Localizable.strings`.

### Badge / chip
- Testo sintetico stile **`DEBUG · Solo lettura`** (EN **«DEBUG · Read-only»**, ES/ZH in execution).
- Aspetto **neutro o arancione** come badge/card ProductPrice diagnostic — **mai** tratto visivo della **CTA primaria consumer** *(no blu “azione principale prod”)*.

### Card summary *(sempre visibile sopra la lista DisclosureGroup dopo il primo caricamento riuscito)*
Se stato `idle` *(nessun tentativo ancora)*, mostrare copy guida corta senza spoof di dati:
1. **`summary.events.count`** — **totale righe nell'ultimo `SyncEventPreviewSummary`** *(puo' essere **50**, indipendentemente dall'UI lista)*.
2. **Ultimo evento:** `domain` • `event_type` • `changed_count`.
3. **Ultimo `created_at`** *(primo elemento `events.first` dopo ordinamento garantito TASK-053)* — `Date.FormatStyle` compatto locale-aware.
4. **`effectiveLimit`** e **nota se `SyncEventPreviewSummary.isLimitClamped`**.
5. **`notConfigured`**: servizio `SupabaseSyncEventPreviewService == nil` o DI equivalente non disponibile — messaggio sintetico localizzato guida tipo **«Servizio debug sync_events non configurato in questa build»** *(EN equivalente)* — **senza crash**, summary minimale *(CA T54-U14)*.
6. **`noSession`/account:** utente **non autenticato/sessione assente** — messaggio sintetico localizzato guida tipo **«Accedi per vedere gli eventi sync»** *(EN equivalente)*; niente token JWT/query string nella card.

### Pulsante unico *(load / refresh / retry)*
*(Label **localizzate** in tutte le lingue progetto TASK-054.)*

| Contesto stato ViewModel *(enum § Architettura + Addendum)* | Titolo pulsante |
|--------------------------------------------------|----------------|
| Prima azione da **`idle`** (nessun caricamento precedente ancora riflesso nella UI aggiornata) | **«Carica eventi»** *(chiave suggerita `options.supabase.syncEvents.button.load`)* |
| Dopo `success*` o `error` | **«Aggiorna eventi»** |

- **Disable** durante `loading` **e** se **`notConfigured`**, **`noSession`**, o quando **`canRunSyncEventsDebugActions`** è falso (**DEC-054-12** — **non** riusare acriticamente solo `canRunAuthenticatedSupabaseActions` se lega anche pull/ProductPrice/manual push non rilevanti per Slice B).

### Loading
- **`ProgressView` inline** (es. affianco a stato testuale) — **proibiti overlay full-screen**/blur TASK-054.

### `successEmpty`
- Empty state leggerezza: SF Symbol sobrio + localized **«Nessun evento sync trovato»** *(EN «No sync events found»)*.

### `error`
- **`Label`** con **`exclamationmark.triangle.fill`**, tint arancione/rosa sobrio.
- Mapping messaggi sanitizzati via **`localizedSupabaseDiagnosticMessage(for:)`** o wrapper dedicato (**no** bearer, **no** query PostgREST raw, **no** stack trace Xcode).
- **Retry:** solo pulsante **«Aggiorna eventi»**.
- **`schemaDrift`**, **`decodingError`**, **`unknown`**, rete/`permissionDeniedOrRLS` → tutti confluiscono nello stato enum **`error`** *(nessun stato UI separato `schemaOrLiveUnknown`)*.

### Lista eventi
- **`DisclosureGroup`** contenitore.
- **`ForEach(displayRows.prefix(20))`** dove `displayRows: [SyncEventDebugDisplayRow]` provengono solo dal ViewModel (**DEC-054-10** — la View non itera **`RemoteSyncEventRow`** grezzi).
- **Cap lista UI = 20**; `.font(.footnote)` · **vietata** tabella/lista JSON raw.
- **`SyncEventDebugDisplayRow`** *(tipo pianificato, stesso modulo ViewModel o `SupabaseSyncEventDebugFormatting`)* campi pubblici verso SwiftUI solo valori già sanitizzati: `id` · `domain` · `eventType` · `changedCount` · `source` breve opzionale · **`createdAtFormatted`** *(string locale-safe)* · `entityIDsShape` / **`entityIDsCount`** · `metadataShape` / **`metadataCount`** · `sanitizedPreview` opzionale **≤48** *(vedi DEC-054-07)*.

### Accessibilità e Dynamic Type
- Nuove label via **`L(...)`**, `accessibilityLabel`/`Hint` su pulsante e DisclosureGroup — supporto Dynamic Type *(no altezza fissa)*.

### Stati ViewModel *(7 casi user-facing — XCTestabile)*

| Stato enum | Sintesi comportamento |
|------------|-----------------------|
| `idle` | Attesa primo load esplicito. |
| `loading` | Fetch in corso — CTA disabilitata — `ProgressView` inline — guard reentrancy / no concurrent fetch (**T54-U15**). |
| `successEmpty` | Risposta OK, **0 eventi**. |
| `successWithEvents` | Risposta OK, `events.count` ≥ **1**. |
| `error` | Errore mappabile *(inclusi schema/decoding/remoto/post-fetch)* — messaggio sanitized (**no** JWT/query dump). |
| `noSession` | Non autenticato / **`sessionMissing`** — CTA spenta · copy tipo *«Accedi per vedere gli eventi sync»*. |
| `notConfigured` | **`supabaseSyncEventPreviewService == nil`** *(o wiring DI assente)* — **non** confondere con logout: copy tipo *«Servizio debug sync_events non configurato in questa build»* — CTA spenta (**T54-U14**). |

**Policy pubblica TASK-054 — niente stato `cancelled` in UI**

- **`cancel()`** *(teardown tecnico)* e **`reset()`** *(logout/cambio account/policy `onDisappear`)*: **annullano** il **`Task`** di fetch in corso; **incrementano** (o comunque aggiornano) **`requestID`/epoch** così da **ignorare** completamenti **stale** (**DEC-054-08**, **T54-U16**); **stato osservabile SwiftUI pubblicato dopo teardown = sempre `idle`** *(buffer/display rows azzerati secondo policy EXECUTION codificata nei test)*.
- **Non** esiste pulsante «Annulla caricamento»: **non** mostrare **copy dedicata né schermata** per caso `cancelled` — analogamente la UI **non** distingue un quinto stato “annullato” percepibile dall’utente.
- *Opzionale implementativo:* caso etichettato **`cancelled`** nel codice sorgente, se rimanesse nel type system, vale **solo** come passaggio interno/transitorio **non** osservabile SwiftUI; **allo steady state pubblicato** dopo `cancel`/`reset` = **`idle`**.

## Architettura *(DEC-054-04 — ViewModel dedicato)*

### Nome tipo e file
- **Preferito:** **`SupabaseSyncEventDebugViewModel`** *(marker **`@MainActor`** obligatorio — Addendum §1)* in **`iOSMerchandiseControl/SupabaseSyncEventDebugViewModel.swift`**.
- **`SupabaseSyncEventDebugLoader`**: ammesso **solo come renome/sync interno** se collision naming — il planning TASK-054 fa riferimento al tipo **`SupabaseSyncEventDebugViewModel`** nei test e nell'OPTIONS wiring.

### Motivazione DEC-054-04
- `OptionsView.swift` e **estremamente denso**. Stato caricamento/async/cancellazione, summary, **`reset` account**, mapping errori **`SupabaseInventoryServiceError`** → stato enum pubblico — **fuori dalla View**.
- XCTest/unit su VM >> snapshot-only.

### Contratto comportamentale *(read-only, volatile RAM)*
- **Classe tipo ViewModel marcata `@MainActor`** (**DEC-054-08**): pubblicazione stato consumata da SwiftUI **solo** sul Main Actor nei casi **`idle` / `loading` / `success*` / `error` / `noSession` / `notConfigured`** *(nessun stato user-facing **`cancelled`** — vedi policy tabella sopra)*. Il **`SupabaseSyncEventPreviewService`** resta **`async`** read-only; dopo `await` si applicano buffer/`requestID`/transizioni sempre coerenti sul **Main Actor** (**DEC-054-08** · **DEC-054-11**).
- **No SwiftData/UserDefaults/File** cache di eventi o summary (*buffer interno `[RemoteSyncEventRow]` eventualmente prima della proiezione in `SyncEventDebugDisplayRow` rimane proprietà private VM — **non leakato** alla View*).
- **Enum stato *user-facing pubblicato* TASK-054:** `idle` · `loading` · `successEmpty` · `successWithEvents` · `error` · `noSession` · **`notConfigured`** *(set chiuso a 7)*.
- **`func loadLatestEvents() async`** — chiama **solo** `service?.loadLatestEvents()` **senza argomenti** se configurato (**default 50**) · se `nil` stato **`notConfigured`** early exit (**no-op fetch** · **no crash**) — concurrency policy § Addendum (*no doppio fetch concorrente in `loading`, `requestID`/task cancellabile*).
- **`func cancel()`** / **`func reset()`** — vedi § **Policy pubblica TASK-054 — niente stato `cancelled` in UI** sopra (**DEC-054-11** · **T54-U06** / **T54-U07**).

### Nessuna mutazione locale business
- **Vietato** modificare catalogo/ProductPrice/SwiftData/baseline dal ViewModel TASK-054.

### Riuso stack TASK-053 *(vietato nuovo PostgREST)*
- `SupabaseSyncEventPreviewService` + fetcher **`SupabaseSyncEventRemoteReader(clientProvider:)`** (+ **`SupabaseClientProvider`** condiviso session-aware DEBUG).
- Nessun'altra `.from("sync_events"...)` fuori da tale stack.

---

## Dependency Injection *(future EXECUTION)*

### `OptionsView.init`
- Aggiungere parametro **`supabaseSyncEventPreviewService: SupabaseSyncEventPreviewService? = nil`** *(o closure/factory allineata al pattern corrente `supabaseManualPushService` / altri OPTIONAL DEBUG — **preferenza minimo churn** da verificare a execution su callsite nel file `OptionsView`/App entry)*.
- **`nil`** → ViewModel pubblica stato **`notConfigured`** + copy dedicata (**non** errore runtime, **non** fallback fetch implicito).

### `@StateObject`, lifecycle VM e **`init`** *(EXECUTION safety)*
- Se **`SupabaseSyncEventDebugViewModel`** viene usato come **`@StateObject`** in `OptionsView`: **assegnarlo nell’`init` di `OptionsView`** passando **`supabaseSyncEventPreviewService: SupabaseSyncEventPreviewService?`** al costruttore del VM **un’unica volta** per lifecycle della view — **vietato** istanziare il VM dentro **`body`** (ricreazioni a ogni render, stato perso / leak logico race).
- **Non** cambiare l’istanza VM “a caso” quando cambia account o il servizio: usare **`reset()`** /**`cancel()`** + bump **`requestID`/epoch** (policy **DEC-054-08** · **DEC-054-11** · **T54-U06/U07**/**T54-U16**), non **`StateObject(wrappedValue: …)`** ricalcolato dal body.
- *Pattern alternativo* (`@ObservedObject` esterno lifecycle App) fuori TASK-054 salvo reviewer — se si resta **`@StateObject`**, vale il vincolo **init-only** sopra.

### Riduzione churn `OptionsView` *(DEC ergonomia)*
- La nuova Section non deve essere un **blocco anonimo lungo dentro `body`**: predisporre computed **`private var syncEventsSection: some View`** *oppure* **`@ViewBuilder private func syncEventsSection() -> some View`** contenente **`SectionHeader`**, contenuto **`@StateObject`** VM (lifecycled come § sopra; **`@ObservedObject`** solo se proprietà `@StateObject` ospitante altrove è esplicitamente decisa) + `Section`, `Label`, **`LabeledContent`**, **`DisclosureGroup`**, **`ProgressView` inline** *(stesso vocabolario visivo delle altre card Supabase DEBUG in `OptionsView` — badge secondario «DEBUG / sola lettura», niente layout custom pesante né overlay globali né viewer JSON)*.
- **Palette:** riusare **`Color.accentColor`**, **`.secondary`**, **`.foregroundStyle`** e tinte già consolidate nel file (**`.orange` / `.green` / `.red`** dove già presenti per stato errore/diagnostica) · **vietati** nuovi hardcode colore gratuiti fuori dal pattern leggibile dalla review diff **minimo**.
- Card/badge **`DEBUG · Solo lettura`** resta **secondario**, non impersona CTA primaria.
- **Se la section crescesse**: preferire **`private` subviews** nello **stesso** `OptionsView.swift` *solo* per minimizz churn; **estratta file Swift separato** OPTIONS solo task futuro se review richiede split (fuori TASK-054 salvo blocker dimensionale).

### Regole DI
- **No nuovo layer network**.
- Reader reale sempre da **`SupabaseClientProvider`** gia' usato Supabase OPTIONS.

### Perimetro **`OptionsView`**: nessuna regressione sezioni esistenti
- EXECUTION deve **solo inserire** la nuova Section **`sync_events`** nel punto fisso (**dopo baseline**, **prima push preflight** — **DEC-054-05**).
- **Vietato**: riordinare, rinominare o mutare comportamento delle sezioni Supabase **`#if DEBUG` esistenti** (auth/Google, diagnostica probe, preview pull sheet, ProductPrice preview/apply, manual push, baseline lettura, collision/preflight) salvo wiring **minimo** per **`supabaseSyncEventPreviewService?`** pass-through init/App se inevitabile.

## Performance *(DEC-054-06 — vincoli confermati)*
- **Fetch default** (nessun argomento a `loadLatestEvents()`): **50** eventi — allineato TASK-053 / `SyncEventPreviewOptions.standardLimit`.
- **Clamp service max:** **200** — nessun wiring UI per superare il clamp in TASK-054.
- **Display cap UI lista:** **20** righe massime iterazione `ForEach` — **DEC-054-06**.
- **Riga/footer conteggio mostrati — formula generalizzata** *(localizzata con parametri)*: **`Mostrate min(20, M) di M`** dove **`M == summary.events.count`** *(totale eventi caricati nell'ultimo fetch)* — es.: *M=0 → «Mostrate 0 di 0»*, *M=5 → «Mostrate 5 di 5»*, *M=50 → «Mostrate 20 di 50»* — aggiorna stringhe EXECUTION (**T54-U18**).
- **Nessuna paginazione**, **nessun timer**, **nessun polling**, **nessun refresh automatico** su `onAppear` / scene phase — solo tap utente su **Carica** / **Aggiorna**.

---

## Privacy / security *(DEC-054-07 + hardening)*

### Divieti TASK-054 *(assoluti)*
- **Non** mostrare **`ownerUserID`** per ogni riga evento.
- **Non** mostrare token, JWT, stringa sessione, query PostgREST/param URL, **liste** barcode o UUID.
- **Non** aggiungere **copy-to-clipboard** TASK-054.
- **Non** fare `print` / os_log / dump console di `metadata`/`entity_ids`/JSON integrale.

### Helper puri / modulo formattazione *(testabili XCTest)*
- File dedicato opzionale **`iOSMerchandiseControl/SupabaseSyncEventDebugFormatting.swift`** se helper multipli (*riduce noise nel ViewModel)* — include **mapper** deterministico **`RemoteSyncEventRow` → `SyncEventDebugDisplayRow`** per **centralizzare** shape/count/preview sanitized (**DEC-054-10**).
- Esporre funzioni **pure** deterministiche su **`SyncEventJSONValue?`** / **`SyncEventJSONValue`** *(e simili)* che producono **solo**:
  1. **Shape testuale localizzata**: `oggetto`, `array`, `stringa`, `numero`, `boolean`, **`vuoto`** *(per `.null`)* — catene annidate **non** esplose in tree view; **un solo** shape label per campo + conteggi dove sotto.
  2. **Conteggio meaningful top-level** dove applicabile *(es. numero chiavi dizionario root; lunghezza array root; per `string`/`number`/`bool` — indicatore **N/A** o **1** sintetico senza valore raw — policy esplicita durante EXECUTION per evitare ambiguità)*.
  3. **Preview opzionale max 48 caratteri** **solo** dopo **sanitizzazione**: strip pattern che assomigliano a JWT, bearer, query `?`, UUID stream, sequenze solo cifre barcode-like lunghe — se post-sanitizzazione stringa vuota → **no preview** *(solo shape+count)*.

### Errori UI
- Reuso **`localizedSupabaseDiagnosticMessage`** pipeline esistente senza append di dettagli tecnici non filtrati.

### Screenshot-safe
- Obiettivo: nessuno schermo OPTIONS TASK-054 con dumping massivo identifier.

---

## Planning — Analisi
- **`OptionsView`** e' gia' la superficie canonica delle operazioni Supabase diagnostica; TASK-053 ha deliberatamente omesso UI — Slice B chiude gap osservabilita' senza allargare superficie Release.
- Il mapping errori di rete/decodifica/sessione e' omogeneo a `SupabaseInventoryServiceError` — riuso localization riduce churn.
- Rischio **drift locale vs prod**: UI deve verbalizzare che la lista riflette solo **attempt read** autenticato, senza garantire equivalenza prod.

---

## Planning — Approccio *(execution futura post **PLANNING REVIEW**)*
1. Implementare **`@MainActor SupabaseSyncEventDebugViewModel`** + **7 stati user-facing** + **`loadLatestEvents`/`cancel`/`reset`** (policy **DEC-054-11**) + fake fetcher TASK-053.
2. Aggiungere helper **`SupabaseSyncEventDebugFormatting`** se necessario *(shape/count/sanitize preview DEC-054-07)* con XCTest puri **prima** o in parallelo wiring UI minimale Options.
3. Integrazione UI **`OptionsView.swift`** sezione **`#if DEBUG`** dopo baseline / prima preflight — **solo** via **`syncEventsSection`** computed (`some View`), wiring DI **`supabaseSyncEventPreviewService?`** *(nessun mega blocco nel `body` inline)* + gate **`canRunSyncEventsDebugActions`** (**DEC-054-12**) + **`@StateObject`** VM creato nell’**`init`** + stringhe **`notConfigured`** / **`noSession`** distinguibili (**DEC-054-09**).
4. **`Localizable.strings`**: IT · EN · ES · zh-Hans — vedere **`### Chiavi Localizable.strings suggerite (non implementate)`** sotto; includere parametri **`Mostrate min(20,M) di M`**.
5. **`SupabaseSyncEventDebugViewModelTests.swift`** + copertura tab § Test futuri.
6. **`rg`/`grep` no-write** include **tutti** i `.swift` nuovi TASK-054 + whitelist token vietati lista utente § Test.
7. `plutil` / duplicate-keys per quattro lingue dopo aggiunta stringhe.
8. Build/test documentati dall'executor + handoff **REVIEW tecnica Claude** prima richiesta DONE utente.
9. **`MASTER-PLAN.md`**: aggiornamento tracking fase/status **solo** durante lifecycle task — **non** marcare TASK-054 DONE dalla sola EXECUTION Codex — **vietato TASK-055** in questo ciclo.

---

## Planning — File coinvolti *(future EXECUTION — lista aggiornata)*
- **`iOSMerchandiseControl/OptionsView.swift`** — solo **integrazione UI minima** `#if DEBUG` + `@StateObject`/`@ObservedObject` VM + binding pulsante — **solo dopo approval planning + override utente EXECUTION**.
- **`iOSMerchandiseControl/SupabaseSyncEventDebugViewModel.swift`** — **preferito/nome canonico** (`@MainActor`, stato + race policy + pubblicazione **`[SyncEventDebugDisplayRow]`** verso SwiftUI).
- **`iOSMerchandiseControl/SupabaseSyncEventDebugFormatting.swift`** — **opzionale** formatter + **`RemoteSyncEventRow` → SyncEventDebugDisplayRow** se eccede dimensioni VM (**DEC-054-07/10**).
- **`iOSMerchandiseControl/it.lproj/Localizable.strings`**, **`en.lproj`**, **`es.lproj`**, **`zh-Hans.lproj`**.
- **`iOSMerchandiseControlTests/SupabaseSyncEventDebugViewModelTests.swift`** — XCTest VM + formatting puri dove applicabile.
- **`iOSMerchandiseControl.xcodeproj/project.pbxproj`** — **solo se** EXECUTION crea nuovi file sorgenti e Xcode lo richiede.
- **`iOSMerchandiseControlApp.swift`** *(o equivalente injection root)* — **solo se inevitabile** per pass-through `SupabaseSyncEventPreviewService?` nel init `OptionsView` — minimizzare diff.
- **`docs/MASTER-PLAN.md`** — aggiornamenti tracking/stato TASK-054 durante avanzamento; **non DONE** falsi durante planning.
- **Non** modificare archivi TASK-052/TASK-053 salvo puntuali xref testuali necessari *(fuori questo turno planning)*.

### Chiavi `Localizable.strings` suggerite *(pianificate — non implementare in PLANNING)*

*(Prefisso comune **`options.supabase.syncEvents.** · IT/EN/ES/zh-Hans in EXECUTION.)*

| Chiave suggerita |
|------------------|
| `options.supabase.syncEvents.header` |
| `options.supabase.syncEvents.badge.readOnly` |
| `options.supabase.syncEvents.button.load` |
| `options.supabase.syncEvents.button.refresh` |
| `options.supabase.syncEvents.state.idle` |
| `options.supabase.syncEvents.state.loading` |
| `options.supabase.syncEvents.state.empty` |
| `options.supabase.syncEvents.state.error` |
| `options.supabase.syncEvents.state.noSession` |
| `options.supabase.syncEvents.state.notConfigured` |
| `options.supabase.syncEvents.summary.loadedCount` |
| `options.supabase.syncEvents.summary.latestEvent` |
| `options.supabase.syncEvents.summary.effectiveLimit` |
| `options.supabase.syncEvents.summary.displayedCount` *(parametri `min(20,M)`, `M`)* |
| `options.supabase.syncEvents.list.title` |
| `options.supabase.syncEvents.field.domain` |
| `options.supabase.syncEvents.field.eventType` |
| `options.supabase.syncEvents.field.changedCount` |
| `options.supabase.syncEvents.field.createdAt` |
| `options.supabase.syncEvents.field.entityIDs` *(etichetta riga sintetica, non JSON)* |
| `options.supabase.syncEvents.field.metadata` |
| `options.supabase.syncEvents.shape.object` |
| `options.supabase.syncEvents.shape.array` |
| `options.supabase.syncEvents.shape.string` |
| `options.supabase.syncEvents.shape.number` |
| `options.supabase.syncEvents.shape.boolean` |
| `options.supabase.syncEvents.shape.empty` |
| `options.supabase.syncEvents.shape.notAvailable` |

---


## Planning — Rischi

| Rischio | Mitigazione planning |
|---------|---------------------|
| Accidental complexity / «feature creep» UI | DisclosureGroup + footer DEV + pulsante unico. |
| Dump JSON / liste ID | Formatter DEC-054-07 + divieto clipboard/console. |
| File `OptionsView.swift` growth | DEC-054-04 ViewModel file separato obbligatorio. |
| Reentrancy doppio tap / double fetch | Stato **`loading`** + gate secondo `load` (**T54-U15**) · `@MainActor` publish atomico (**DEC-054-08**). |
| Risultati tardivi dopo `reset`/account switch | **`requestID` monotonic** o **`Task`** cancellabile — drop mismatch (**T54-U16**). |
| Divergenza Android bulk semantics TASK-068 | Messaggio footer «campione osservabile» limitato righe+. |

---

## Planning — Test futuri *(pianificati — non implementati in questo turno PLANNING)*

### Unit / ViewModel XCTest (`SupabaseSyncEventDebugViewModelTests`)

| Codice | Scenario | Tipo |
|--------|-----------|------|
| T54-U01 | idle → `loading` → `successWithEvents` *(fake N≥1)* | UNIT |
| T54-U02 | `successEmpty` *(fake 0 righe)* | UNIT |
| T54-U03 | `sessionMissing` / `noSession` gate | UNIT |
| T54-U04 | `schemaDrift` mapping → stato **`error`** + messaggio sanificato pathway | UNIT |
| T54-U05 | `decodingError`/corrupt JSON pathway → **`error`** | UNIT |
| T54-U06 | `cancel()` mentre `loading` → **Task cancellato**, risultati **stale ignorati**, **stato pubblicato `idle`** (nessuno stato user-facing **`cancelled`**) | UNIT |
| T54-U07 | **`reset()`** dopo success *(o teardown account)* → buffer/display clear + **`requestID` bump** dove applicabile + **stato pubblicato `idle`**; completamenti tardivi **ignorati** | UNIT |
| T54-U08 | UI modello lista: **`prefix(20)`** quando fake ritorna **50** eventi — assertion su count esposto ViewModel/UI-state struct | UNIT |
| T54-U09 | **`effectiveLimit == 50`** mostrato/derivabile da ultimo summary senza override argomento VM | UNIT |
| T54-U10 | Propagazione `isLimitClamped` true/false verso summary UI *(assert su presenter/adapter se separati)* | UNIT |
| T54-U11 | `entity_ids` **nil** vs **`.object`/`.array`** — shape helper output atteso DEC-054-07 | UNIT |
| T54-U12 | `metadata` shape + conteggio top-level chiavi **senza** raw dump accessor test string | UNIT |
| T54-U13 | Formatter preview ≤48 dopo sanitizzazione — stringhe simulate JWT/barcode-like → preview vuota | UNIT |
| T54-U14 | `service == nil` → stato **`notConfigured`**, **CTA disabilitata**, **nessun crash** | UNIT |
| T54-U15 | Doppio `loadLatestEvents()` mentre `loading` **non avvia due fetch concorrenti** | UNIT |
| T54-U16 | Completamento fetch **ritardato** dopo `reset()` *(o cambio account simulato via bump `requestID`)* → risultato **scartato** — stato UI coerente con ultima richiesta valida | UNIT |
| T54-U17 | ViewModel/strato pubblico osservabile espone **`[SyncEventDebugDisplayRow]`** / projections safe — **non** espone **`[RemoteSyncEventRow]`** alla View (**API surface review / assert test su tipo esposto**). | UNIT / STATIC |
| T54-U18 | Formula **«Mostrate min(20, M) di M»** parametrizzata per **M ∈ {0, 5, 20, 50}** *(assert contenuto string/modello presenter)* | UNIT |

### Repo hygiene / regressione localization

| Codice | Descrizione | Tipo |
|--------|-------------|------|
| T54-G01 | **Grep no-write** su **tutti** i `.swift` introdotti TASK-054 — vietati substring: `.insert(`, `.upsert(`, `.update(`, `.delete(`, `.rpc(`, `.channel(`, `.subscribe(`, `record_sync_event`, `BGTask` | STATIC |
| T54-G02 | `plutil -lint` + scan duplicate keys **`Localizable.strings`** — **IT/EN/ES/zh-Hans** | STATIC/BUILD-light |
| T54-G03 | Accessibilità base VoiceOver pulsante/disclosure (**manuale o UI test se esiste infra — default MANUAL progetto**) | MANUAL |

### Review statico opzionale
| Codice | Descrizione | Tipo |
|--------|-------------|------|
| T54-R01 | **OptionsView** diff EXECUTION futura **non introduce** nuove CTA mutate catalog/sync automatico fuori glossary | STATIC review |
| T54-G04 | **Grep/static review**: `syncEventsSection` **`OptionsView` non legge/binda** **`entity_ids`/`metadata`** raw (**no** `\.entityIDs`/`.metadata` su DTO dalla View — solo **`SyncEventDebugDisplayRow`**) | STATIC |

---

## Criteri di accettazione *(contratto TASK-054 — fase PLANNING)*
1. Planning completo + addendum sicurezza: **`@MainActor`**, **`notConfigured`**, **`SyncEventDebugDisplayRow`**, race/`requestID`, **`syncEventsSection`**, formula **«Mostrate min(20,M) di M»**, test/grep estesi (**T54‑U14…U18**, **T54‑G04**).
2. **`docs/TASKS/TASK-054-supabase-sync-events-debug-ui-readonly-ios.md`** aggiornato *(questo file)*.
3. **`docs/MASTER-PLAN.md`**: progetto ACTIVE + TASK-054 PLANNING quando applicabile durante tracking *(non modificato automaticamente questo micro-turno rifinitura TASK-054 se gia' allineato)*.
4. **Nessuna** patch Swift / test / `project.pbxproj` / **build** / **XCTest** / **Supabase live** mentre TASK-054 resta solo **PLANNING**.
5. Handoff stato documentale: **READY FOR PLANNING REVIEW** *(≠ READY FOR EXECUTION)* — EXECUTION Codex solo dopo revisione pianificazione + override utente distinti workflow progetto.
6. **TASK-054 NON DONE** — non dichiarare chiusura in questo planning turn.
7. **TASK-055** non creato/non toccato.

---

## Execution *(Codex)*
### 2026-05-06 — Execution patch applicata

**User override ricevuto:** EXECUTION approvata esplicitamente per `docs/TASKS/TASK-054-supabase-sync-events-debug-ui-readonly-ios.md`, nonostante tracking iniziale ancora `ACTIVE / PLANNING`. Impatto tracking: task portato a `ACTIVE / REVIEW` dopo patch e verifiche; **non DONE**.

**File modificati:**
- `iOSMerchandiseControl/SupabaseSyncEventDebugFormatting.swift`
- `iOSMerchandiseControl/SupabaseSyncEventDebugViewModel.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseSyncEventDebugViewModelTests.swift`
- `docs/TASKS/TASK-054-supabase-sync-events-debug-ui-readonly-ios.md`
- `docs/MASTER-PLAN.md`

**Implementato:**
- ViewModel `@MainActor final class SupabaseSyncEventDebugViewModel` con stati user-facing `idle`, `loading`, `successEmpty`, `successWithEvents`, `error`, `noSession`, `notConfigured`.
- `loadLatestEvents() async` chiama solo `SupabaseSyncEventPreviewService.loadLatestEvents()` senza argomento; fetch default **50**; doppio load durante `loading` ignorato.
- `cancel()` e `reset()` tornano a `idle`, cancellano/invalidano il task in corso e scartano risultati tardivi via `requestID`.
- Display model safe `SyncEventDebugDisplayRow` + `SyncEventDebugDisplaySummary`; la View non espone `[RemoteSyncEventRow]`.
- Formatter safe per `SyncEventJSONValue`: shape/count top-level per object/array/string/number/boolean/null/notAvailable; preview opzionale sanitizzata max 48 caratteri; niente raw JSON, liste UUID/barcode, token/JWT/session/query string.
- UI `#if DEBUG` in `OptionsView` come `syncEventsSection`, posizionata dopo baseline Supabase e prima di preflight/manual push; stile nativo con `Section`, `SectionHeader`, `Label`, `LabeledContent`, `DisclosureGroup`, `ProgressView`, badge `DEBUG · Solo lettura`.
- Gate dedicato `canRunSyncEventsDebugActions`, separato da `canRunAuthenticatedSupabaseActions`, basato su sessione/auth valida, servizio sync events configurato e ViewModel non loading.
- DI `supabaseSyncEventPreviewService` da `iOSMerchandiseControlApp` → `ContentView` → `OptionsView`; `@StateObject` creato nell'`init`.
- Localizzazioni IT/EN/ES/zh-Hans con prefisso `options.supabase.syncEvents.*`.
- Nessuna modifica a `project.pbxproj`: il progetto usa root group filesystem-synchronized e build/test hanno incluso i nuovi `.swift`.

**Check eseguiti (risultato reale):**
- ✅ ESEGUITO — Build Debug iOS: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **PASS**. Primo tentativo con `OS=latest` non eseguibile per destination non risolta; rilanciato su destination disponibile `OS=26.2`.
- ✅ ESEGUITO — XCTest mirati TASK-054: `xcodebuild ... test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventDebugViewModelTests` → **PASS 14/14**.
- ✅ ESEGUITO — XCTest regressione TASK-053: `xcodebuild ... test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests` → **PASS**.
- ✅ ESEGUITO — `plutil -lint` sulle quattro `Localizable.strings` → **OK**.
- ✅ ESEGUITO — grep no-write sui nuovi file TASK-054 (`.insert(`, `.upsert(`, `.update(`, `.delete(`, `.rpc(`, `.channel(`, `.subscribe(`, `record_sync_event`, `BGTask`) → **nessun match**.
- ✅ ESEGUITO — static review `OptionsView` per `.metadata`, `.entityIDs`, `RemoteSyncEventRow`, `SyncEventJSONValue` → **nessun match**.
- ✅ ESEGUITO — `git diff --check` → **PASS**.
- ✅ ESEGUITO — Coerenza planning/criteri: sezione solo `#if DEBUG`, read-only, no write Supabase, no RPC, no realtime, no BGTask, no polling, no Supabase live, no raw payload UI/log, no owner per riga, no clipboard → **verificato staticamente**.

**Warning / note:**
- Build/test mostrano il warning AppIntents metadata gia' noto del progetto/ambiente (`No AppIntents.framework dependency found`); nessun warning compiler emerso dai nuovi file TASK-054.
- Test Simulator/manuale UI non eseguito: non richiesto esplicitamente dal task/utente per questa execution.
- Nessuna chiamata Supabase live eseguita; i test usano fake/mock fetcher.

**Rischi rimasti:**
- Validazione visuale/manuale della nuova section in Simulator resta eventuale follow-up di review, non eseguita in questa patch.
- La UI mostra shape/count top-level e non esplode JSON annidato: scelta intenzionale privacy-safe conforme al planning.

## Fix *(Codex)*
### 2026-05-06 — Fix mirati da technical review

**Fix applicati:**
- `OptionsView`: rimossa la ripetizione del titolo dentro la Section `sync_events`; il badge `DEBUG · Solo lettura` resta secondario e la copy idle viene mostrata solo nello stato `idle`.
- `SupabaseSyncEventDebugFormatting`: rimosso helper non usato con stringa italiana hardcoded per il displayed count; la UI resta localizzata via `Localizable.strings`.
- `SupabaseSyncEventDebugViewModelTests`: aggiunto test esplicito `reset()` durante `loading` con risultato tardivo ignorato; sostituito assertion fragile su `String(describing: type(of: ...))` con verifica compile-time su `[SyncEventDebugDisplayRow]`.
- Localizzazioni IT/EN/ES/zh-Hans: rimosse chiavi TASK-054 inutilizzate evidenti e rifinite piccole traduzioni di label usate.

**Perimetro fix:**
- Nessun refactor ampio di `OptionsView`.
- Nessuna nuova dipendenza.
- Nessuna nuova feature sync/push/outbox/realtime.
- Nessuna modifica Android/schema/RLS/RPC/migration.
- **TASK-055 non aperto.**

---

## Review *(Claude / Umano)*
### 2026-05-06 — Technical review + fix *(Codex, user override)*

**Esito review:** `APPROVED_FIXED_DIRECTLY / DONE`.

**Cosa e' stato controllato:**
- Architettura: `SupabaseSyncEventDebugViewModel` `@MainActor`, stato pubblico a 7 casi, `@StateObject` creato in `OptionsView.init`, DI `supabaseSyncEventPreviewService` coerente, gate dedicato `canRunSyncEventsDebugActions`, `notConfigured` distinto da `noSession`, `cancel()`/`reset()` a `idle`, requestID/task cancellabile, doppio load ignorato.
- Privacy/sicurezza: nessuna write Supabase, nessun RPC/realtime/BGTask/polling/clipboard, nessun raw dump di `metadata`/`entity_ids`, nessun `ownerUserID` mostrato per riga, formatter preview max 48 e sanitizzazione per token/JWT/session/query/UUID/barcode-like.
- UI/UX: Section solo `#if DEBUG`, posizionata dopo baseline Supabase e prima del preflight/manual push, stile SwiftUI nativo (`Section`, `SectionHeader`, `Label`, `LabeledContent`, `DisclosureGroup`, `ProgressView` inline), badge secondario, CTA load/refresh, stati loading/empty/error/noSession/notConfigured, display cap 20 su fetch default 50.
- Efficienza/cleanup: nessun side effect nel rendering, nessun task di fetch lasciato senza cancellazione VM, localizzazioni inutilizzate evidenti rimosse, test fragile sostituito, helper hardcoded non usato rimosso.
- Localizzazioni: IT/EN/ES/zh-Hans presenti, parametri `%d` coerenti, duplicate keys assenti.
- Diff hygiene: `git diff --stat`, `git diff`, `git status --short` controllati; i tre file untracked sono attesi e fanno parte della patch TASK-054.

**Comandi eseguiti e risultato reale:**
- ✅ ESEGUITO — Build Debug iOS: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **PASS**.
- ✅ ESEGUITO — XCTest TASK-054: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventDebugViewModelTests` → **PASS 15/15**.
- ✅ ESEGUITO — XCTest regressione TASK-053: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests` → **PASS 10/10**.
- ✅ ESEGUITO — `plutil -lint iOSMerchandiseControl/it.lproj/Localizable.strings iOSMerchandiseControl/en.lproj/Localizable.strings iOSMerchandiseControl/es.lproj/Localizable.strings iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` → **OK su tutte e quattro**.
- ✅ ESEGUITO — duplicate localization keys scan con `awk | sort | uniq -d` sulle quattro `Localizable.strings` → **nessun duplicato**.
- ✅ ESEGUITO — static no-write grep su nuovi file TASK-054 (`.insert(`, `.upsert(`, `.update(`, `.delete(`, `.rpc(`, `.channel(`, `.subscribe(`, `record_sync_event`, `BGTask`) → **nessun match**.
- ✅ ESEGUITO — static `OptionsView` raw DTO grep (`.metadata`, `.entityIDs`, `RemoteSyncEventRow`, `SyncEventJSONValue`) → **nessun match**.
- ✅ ESEGUITO — `git diff --check` → **PASS**.
- ✅ ESEGUITO — review manuale diff completo (`git diff`) + file non tracciati (`git status --short`) → **nessun file fuori scope rilevato**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: build/test mostrano solo warning AppIntents metadata gia' noto (`No AppIntents.framework dependency found`), non attribuito a TASK-054.

**Conferme scope:**
- Nessuna chiamata Supabase live eseguita.
- Nessuna write Supabase / RPC / realtime / background / polling automatico / clipboard.
- Nessuna modifica Android / schema / RLS / migration.
- **TASK-055 non aperto.**

---

## Decisioni
- **DEC-054-01**: DIAG UI **solo DEBUG build** — nessuna regressione Release binary surface.
- **DEC-054-02**: Nessun refresh automatico; **solo** azione utente sul pulsante (**no** polling / timer / refresh silenzioso su `onAppear`).
- **DEC-054-03**: Prima versione TASK-054 — nessuna presentazione integrale JSON `metadata`/`entity_ids` in UI/console; ora dettaglio operativo affidato a **DEC-054-07** (formatter).
- **DEC-054-04**: **`SupabaseSyncEventDebugViewModel`** obbligatorio — logica stato/async/cancel/reset/privacy-binding **fuori da** `OptionsView`.
- **DEC-054-05**: Section dedicata **`sync_events` DEBUG** posizionata **dopo baseline** **e prima** Section preflight/manual push *(ordine fisso)*.
- **DEC-054-06**: **Fetch implicito max 50** *(nessun argomento `loadLatestEvents()`)* · **lista UI max 20** · stringa sintetizzata parametri **`displayedCount = min(20, M)`**, **`total M`** → copy localizzato **`Mostrate min(20,M) di M`** *(vedi DEC generale PERFORMANCE + **T54-U18**)*.
- **DEC-054-07**: **`entity_ids`** e **`metadata`** — helper puri espongono **solo** shape localizzato (`oggetto`/`array`/…/`vuoto`) + **conteggi top-level** ammessi · preview **≤48** solo dopo sanitizzazione · vietati raw dump · **vietato clipboard** TASK-054 · vietato **`owner_user_id`/UUID owner per riga**.
- **DEC-054-08**: **`SupabaseSyncEventDebugViewModel` `@MainActor`** · pubblicazione stato UI sul main actor · **`requestID`/epoch monotonic** + **`Task` fetch cancellabile** per mitigare **race** e **risultati tardivi** dopo `reset()`/cambio account (**T54-U15**/**T54-U16**).
- **DEC-054-09**: Stato **`notConfigured`** (**service `nil`/DI assente**) **separato** da **`noSession`** (**autenticazione**) — messaggi UI distinti, **CTA disabilitata** in entrambi (**T54-U14**).
- **DEC-054-10**: La **`OptionsView`**/`syncEventsSection` lega SwiftUI **solo** a **`[SyncEventDebugDisplayRow]`** e stringhe/numerici di summary già safe; **vietato** che la View legga/bindi **`RemoteSyncEventRow`**, **`SyncEventJSONValue`** o **`entity_ids`/`metadata` raw dal DTO** (**T54-G04**, **T54-U17**).
- **DEC-054-11**: **`cancel()`** e **`reset()`** → **annullano** il task di fetch, **scartano** completamenti **stale**, pubblicano **sempre `idle`** come stato osservabile · **nessuno** stato user-facing **`cancelled`** (assenza CTA «Annulla») — **T54-U06**/**T54-U07**.
- **DEC-054-12**: Gate UI dedicato **`canRunSyncEventsDebugActions`** — **non** riuso acritico di **`canRunAuthenticatedSupabaseActions`** se dipende da servizi non necessari (pull preview, diagnostics inventory, ProductPrice, manual push); dipendenze **solo** DEBUG + auth/sessione + **`supabaseSyncEventPreviewService != nil`** + VM non **`loading`** + (*opz.*) auth non in transizione; messaggi **`notConfigured`** vs **`noSession`** distinti (**DEC-054-09**).

---

## Roadmap EXECUTION futura consigliata *(solo dopo **PLANNING REVIEW OK** + **user override EXECUTION**)*
1. **`SupabaseSyncEventDebugFormatting.swift`** (se necessario) + XCTest helper puri.
2. **`@MainActor SupabaseSyncEventDebugViewModel`** + **7 stati user-facing** + **`loadLatestEvents()`/`cancel()`/`reset()`** (**→ `idle` pubblico**, **T54-U06/U07**) + race guard (**requestID** / **Task**) + **`[SyncEventDebugDisplayRow]` published** · fake **`SupabaseSyncEventPreviewFetching`**.
3. **`SupabaseSyncEventDebugViewModelTests.swift`** secondo tab T54-U*.
4. UI **`OptionsView`**: dopo baseline (**DEC-054-05**) — inline nel `body` **solo** `syncEventsSection` computed + wiring **`supabaseSyncEventPreviewService?`** + gate **`canRunSyncEventsDebugActions`** (**DEC-054-12**) + **`@StateObject`** VM in **`init`** (§ Dependency Injection).
5. **Localizzazioni** IT/EN/ES/zh-Hans — pulsanti · empty/error/`notConfigured`/`noSession` · formula **`Mostrate min(20,M) di M`** (**T54-U18**).
6. Composizione produzione **`SupabaseSyncEventRemoteReader`** + service TASK-053 + grep **T54-G01** + **T54-G04** + **`plutil` T54-G02**.
7. Build/test documentati nell' Execution + handoff **REVIEW tecnica** pre-DONE utente.

---

## Rischi rimasti *(post-planning documentale)*
- Il mapping **shape/count** per `SyncEventJSONValue` annidato necessita' decisione execution su definizione esatta di «top-level count» vs alberi profondi — documentare scelta minima nel ViewModel/fake tests.
- Aggiunta file Swift richiede inevitabilmente `project.pbxproj` in EXECUTION — pianificare diff minimo.

---

## Addendum — execution-ready hooks *(solo planning, 2026-05-06)*

> Sintesi mirata (**non** sostituisce le sezioni superiori consolidate) · **TASK-054 ACTIVE / PLANNING** · handoff **`READY FOR PLANNING REVIEW`** *(≠ READY FOR EXECUTION)*.
> **Prevalenza**: in caso di sovrapposizione tra sezioni, le **Decisioni DEC-054-*** e questo **Addendum** (hooks execution-ready) **prevalgono** perché più specifici — evitare altre duplicazioni oltre questo livello sintetico.

1. **`@MainActor`** — `SupabaseSyncEventDebugViewModel` come tipo **`@MainActor`**; **7 stati *user-facing* pubblicati**: `idle`/`loading`/`success*`/`error`/`noSession`/`notConfigured` (**DEC-054-09** · **DEC-054-11**). **`SupabaseSyncEventPreviewService`** resta **`async` read-only**; bridging post-`await` sul main actor (**DEC-054-08**).

2. **`notConfigured` vs `noSession`** — **`service == nil`** (o DI equivalente) ⇒ `notConfigured` + *«Servizio debug sync_events non configurato in questa build»*. Assenza autenticazione/sessione ⇒ `noSession` + *«Accedi per vedere gli eventi sync»*. **CTA disabilitata** in entrambi (**DEC-054-09**, **T54-U14**).

3. **`SyncEventDebugDisplayRow`** — unico payload row-level verso `OptionsView`; niente `RemoteSyncEventRow`/`SyncEventJSONValue` esposto alla View (**DEC-054-10**, **T54-U17**).

4. **Race/cancellazione** — **`loading`**: ignore second **`loadLatestEvents()`** senza nuovo fetch parallelo (**T54-U15**). **`requestID`/epoch monotonic + `Task` cancellabile** — completamenti tardivi dopo **`reset()`/cambio account** ignorati (**T54-U16**). **`cancel()`**/teardown mentre fetch attivo ⇒ **cancel task**, **`requestID` invalidation coerente**, **ignora stale**, pubblica **`idle`** (**DEC-054-08** · **DEC-054-11** · **T54-U06**).

5. **`OptionsView`** — UI sync events dentro **`private var syncEventsSection: some View`** o **`@ViewBuilder private func syncEventsSection()`**; **`body`** resta sintetico. Subview **`private`** aggiuntive nello **stesso** file prima di split file esterni.

6. **UI nativa confermata** — Section dopo baseline / prima preflight; componenti come § **Riduzione churn** + palette/tinte coerenti con card DEBUG esistenti (**no** nuova estetica custom). Elenco **`Mostrate min(20, M) di M`** (**T54-U18**).

7. **Test aggiuntivi** già nella tab (**T54-U14…U18**, **T54-G04**).

8. **Gate EXECUTION:** **`canRunSyncEventsDebugActions`** — vedi § **UX/UI — Gate dedicate** (**DEC-054-12**); CTA/disable allineati a questo bool + stato VM (**`notConfigured`**/**`noSession`**/**`loading`**).

9. **`@StateObject` + `OptionsView.init`** — VM creato nell’**`init`**, **mai** nel **`body`**; teardown account/servizio via **`cancel`/`reset`/requestID, non nuova istanza da render.

---

## Handoff post-execution *(Codex → Claude / Technical Review)*
### **READY FOR TECHNICAL REVIEW — TASK-054 EXECUTION PATCH APPLIED**

- **TASK-054**: **ACTIVE / REVIEW** — **non DONE**.
- Patch applicata secondo override utente: UI DEBUG read-only `sync_events` in `OptionsView`, ViewModel/formatter safe, localizzazioni e XCTest.
- Verifiche PASS documentate in § Execution.
- **Nessuna** chiamata Supabase live eseguita.
- **Nessuna** write Supabase, `record_sync_event`, outbox, realtime/background, polling, RPC, clipboard, raw payload dump, Android, schema/migration/RLS, `service_role`, TASK-055.
- Prossimo passo: review tecnica Claude / umano. Eventuali richieste puntuali tornano in fase **FIX**, poi nuovo handoff a **REVIEW**.

## Handoff finale *(Codex → Utente)*
### **TASK-054 DONE — TECHNICAL REVIEW + FIX COMPLETE**

- **TASK-054**: **DONE / Chiusura** su user override.
- Review tecnica completa eseguita; fix mirati applicati; build/test/lint/grep/diff hygiene PASS.
- Nessuna chiamata Supabase live.
- Nessuna write Supabase, RPC, realtime, BGTask, polling automatico, clipboard, raw payload dump, Android, schema/RLS/migration o TASK-055.
