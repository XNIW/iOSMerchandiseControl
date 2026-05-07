# TASK-061 — Supabase `sync_events` manual outbox drain — UI DEBUG iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-061 |
| **Titolo** | Supabase sync_events manual outbox drain UI DEBUG iOS |
| **File task** | `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 15:33 -04 *(REVIEW tecnica severa APPROVED_FIXED_DIRECTLY; fix piccoli applicati direttamente; TASK-061 DONE / Chiusura; workspace IDLE; nessun TASK-062.)* |
| **Ultimo agente** | Claude / Reviewer+Fixer |

## Dipendenze

- **Dipende da**
  - **TASK-060** (**DONE / Chiusura**) — `SyncEventOutboxDrainService`, drain manuale via `any SyncEventRecording`, replay TASK-059, bounded batch, reentrancy owner-scoped, outcome `SyncEventOutboxDrainOutcome` / `SyncEventOutboxDrainStatus`.
  - **TASK-059** (**DONE**) — `makeRecordRequestForReplay`, payload JSON outbox.
  - **TASK-058** (**DONE**) — `SupabaseSyncEventLiveRecorder` / `SyncEventRecording` live boundary.
  - **TASK-057** (**DONE**) — enqueue locale in outbox.
  - **TASK-054** (**DONE**) — pattern UI DEBUG `OptionsView` + `SupabaseSyncEventDebugViewModel` read-only.
- **Sblocca** *(opzionale, fuori da questo file)* — smoke manuale sviluppatore su drain da UI; eventuali task su recovery `sending` stale, retention outbox, ecc. restano separati e **non** parte di TASK-061.

## Scopo

Pianificare una **UI DEBUG** iOS **minima e sicura** sotto `#if DEBUG` in **`OptionsView`** (sezione **Avanzata / Supabase DEBUG**, coerente con le card DEBUG esistenti) che:

- mostri uno **stato sintetico** dell’outbox locale `SyncEventOutboxEntry` (dominio enqueue TASK-057 / drain TASK-060);
- consenta un **unico drain manuale** innescato dall’utente sviluppatore, tramite **`SyncEventOutboxDrainService.drainOnce`** e un **`SyncEventRecording`** di produzione (es. live recorder TASK-058) **solo quando l’utente preme il pulsante**;
- presenti un **risultato privacy-safe** (conteggi/codici/status, **mai** payload grezzo né dati identificativi di business).

**Separazione obbligatoria (UX / safety — futura EXECUTION):**

| Azione | Natura | Comportamento ammesso |
|--------|--------|------------------------|
| **Aggiorna conteggi** | **Read-only**, **locale**, sicura | Può essere invocata al bisogno e **ammessa su apertura card** (es. `onAppear` → solo `refreshCounts()`). **Nessuna** rete, **nessun** recorder/RPC. |
| **Drena outbox sync_events** | **Remota**, **manuale** | **Solo** su tap esplicito sull’CTA primaria **e** sempre dopo **conferma nativa** (`confirmationDialog` / `alert`) **prima** di `drainOnce`. |

`onAppear` della card può al massimo chiamare **`refreshCounts()`** (**solo** con sessione **e** `ownerUserID` validi — **§ Auth / owner state**), in modo **controllato** (**D61-14**, **§ 4.4**); **non** deve mai chiamare **`drainOnce`**, **`SyncEventRecording.record`**, RPC, recorder live né qualsiasi invio remoto.

**Questo task è solo PLANNING:** nessuna modifica Swift, nessun build, nessun XCTest eseguito in questo turno.

---

## Fonti lette (planning — vincolo di citazione)

### Documentazione iOS (workspace)

- `docs/MASTER-PLAN.md` — contesto tracking (TASK-061 **ACTIVE / PLANNING** al momento del planning); **TASK-060** ultimo completato **DONE**; **TASK-052** **BLOCKED / superseded**, **non DONE**.
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md` — G2 implementata: servizio drain **senza** UI / call site automatico / auto-drain.
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md` — Slice G1 replay / payload fidelity.
- `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md` — recorder live isolato, RPC solo nel transport.
- `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md` — enqueue locale terminale, no rete.

### Codice iOS (stato post–TASK-060 — Git locale allineato a `origin` `6bb3d9f`)

- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift` — API `drainOnce`, outcome, errori `invalidOwnerUserID`, `localSaveFailed`, stati `noWork`, `alreadyRunning`, `drained`, `partiallyDrained`, `blockedPayloadReplay`, `blocked`, `networkFailed`.
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift` — `SyncEventOutboxLocalStore.fetchRetryable` / **`fetchCounts(ownerUserID:now:)`** → `SyncEventOutboxCounts` (**pending**, **retryable**, **blocked**, **dead**, **sent**, **localOnly**); **nessun campo “failed” nominale** separato: i fallimenti ritentabili restano in stato `failedRetryable` e rientrano in **`retryable`** quando `isRetryable`.
- `iOSMerchandiseControl/SyncEventRecording.swift` — protocollo `SyncEventRecording` / `SyncEventRecordRequest`.
- `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift` — implementazione live (per produzione DEBUG controllata dall’utente).
- `iOSMerchandiseControl/OptionsView.swift` — `#if DEBUG`, `SupabaseSyncEventDebugViewModel`, `SupabasePushPreflightViewModel`, gate auth(s) esistenti.
- `iOSMerchandiseControl/SupabaseSyncEventDebugViewModel.swift` — pattern ViewModel DEBUG: `idle` / `loading`, `requestID`, cancellazione, messaggi sanificati.
- Localizzazioni: `it.lproj`, `en.lproj`, `es.lproj`, `zh-Hans.lproj` — chiavi sotto namespace `options.supabase.*` (estendere con nuove chiavi **solo** in EXECUTION futura).

### Supabase (solo lettura — planning)

- `/Users/minxiang/Desktop/MerchandiseControlSupabase/MASTER_PLAN.md` — contesto roadmap backend/sync_events (workspace separato; **nessuna** azione live richiesta da TASK-061).
- `MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql` — tabella `sync_events`, RPC **`record_sync_event`** con **`returns public.sync_events`** (singola riga), vincoli `changed_count` (incl. upper bound lato SQL).

### Android (solo riferimento funzionale — **nessun** file Kotlin letto in questo turno)

Repo `MerchandiseControlSplitView` **non** presente sul percorso indicato in workspace locale; si usa la **sintesi** già in TASK-052 / TASK-060 / TASK-054:

- **TASK-061 Android** (hardening `sync_events`, fallback full sync) — principio: diagnostica **privacy-safe**; quando gli eventi incrementali non bastano, **full sync** resta percorso separato (**fuori** TASK-061 iOS).
- **TASK-070 Android** — **head-of-line retry**: query su subset **ritentabile**; allineamento concettuale con `fetchRetryable` iOS (TASK-060).
- **TASK-071 Android** — mismatch **`changed_count`** vs volumi reali / **PayloadValidation**; su iOS il vincolo **0…1000** resta **bloccante** pre-RPC (NESSUNA modifica policy in TASK-061).
- **TASK-068 Android PARTIAL** — bulk/massivo: rischio **validazione** e dimensioni; UI DEBUG iOS **non** deve fare validazione dataset live obbligatoria.

---

## 1. Stato attuale iOS (post TASK-060)

| Voce | Stato |
|------|--------|
| **TASK-060** | **DONE** — `SyncEventOutboxDrainService` esiste; XCTest dedicati in `SyncEventOutboxDrainServiceTests`. |
| **Call site / UI** | **Assenti** — nessun wiring in `OptionsView` o altrove; grep confermato in chiusura TASK-060. |
| **Progetto (tracking)** | Con TASK-061 aperto: **ACTIVE** / task attivo **TASK-061** **PLANNING** (vedi `docs/MASTER-PLAN.md`). |
| **TASK-052** | **BLOCKED / superseded by TASK-053**, **non DONE** (invariato). |

---

## 2. Riferimento Android (funzionale)

- Android ha **hardening**, **logging strutturato** e **fallback full sync** quando il solo filo `sync_events` non copre lo stato reale del catalogo/prezzi.
- **TASK-070**: mitigazione **head-of-line** a livello app (coda che non resta bloccata dietro entry non ritentabili); iOS ha già **filtro retryable + skip in-process** nel drain TASK-060.
- **TASK-071**: segnalazione **`changed_count` > 1000** / validazione payload RPC — l’UI DEBUG iOS deve **riflettere** esiti **blocked/contract** sanificati, **senza** cambiare contratto backend o client.
- **TASK-068 PARTIAL**: attenzione a push bulk — la UI DEBUG **non** sostituisce validazione dataset né push Product/catalog.

---

## 3. Riferimento Supabase

- `sync_events` + RPC **`record_sync_event`** sono già definiti nella migration locale citata; ambiente live/dev è gestito altrove.
- RPC **`returns public.sync_events`**: **una riga** — coerente con decoder/recorder iOS TASK-058.
- Limite **`changed_count`** (0…1000 nel contratto locale/validator) resta **invariato**; eventuale **TASK-072** backend è **fuori perimetro** TASK-061.
- **Nessuna** modifica SQL, **nessun** `db push`, **nessun** test RPC live nel planning TASK-061.

---

## 4. Design proposto (solo per futura EXECUTION — non implementare ora)

### 4.1 `SyncEventOutboxDrainDebugViewModel` (futuro)

`@MainActor`, `ObservableObject`, analogo **requestID** / guard **double-tap** a `SupabaseSyncEventDebugViewModel`: incrementare `requestID` per operazioni async; ignorare callback con ID obsoleto.

**Stati UI proposti:**

| Stato | Significato |
|-------|-------------|
| **idle** | Nessuna operazione in corso (conteggi possono essere già noti). |
| **loadingCounts** | `refreshCounts()` in corso — solo lettura locale. |
| **draining** | `confirmDrain()` ha avviato `drainOnce` — rete/recorder in uso. |
| **result** | Ultimo esito drain disponibile per copy inline **privacy-safe** (da `SyncEventOutboxDrainOutcome` / errori mappati). |
| **error** | Errore surfaceabile in modo generico (es. refresh conteggi fallito, auth/owner), **senza** payload/PII. |

**API futura proposta:**

| Metodo / proprietà | Comportamento |
|--------------------|---------------|
| **`refreshCounts()`** | **Solo** lettura locale tramite `SyncEventOutboxLocalStore.fetchCounts(ownerUserID:now:)` quando **sessione Supabase** e **`ownerUserID`** UUID sono **validi** (**§ Auth / owner state**). Imposta **`loadingCounts`** durante il fetch. **Mai** chiama `drainOnce`, recorder o RPC. |
| **`requestDrainConfirmation()`** | Prepara la conferma UI (es. stato interno “modalità conferma” o solo uso dalla View): **non** esegue drain. |
| **`confirmDrain()`** | **Unico** punto che invoca `SyncEventOutboxDrainService.drainOnce(ownerUserID:limit:fetchScanLimit:)` con **`limit`** = **`selectedLimit`** (preset). **`fetchScanLimit`**: passare **`nil`** affinché il service usi **default/cap prudenziale** interno (TASK-060); **oppure** costante interna documentata in EXECUTION — **mai** valorizzato da input utente (**D61-18**). Transita in **`draining`**; al termine aggiorna **`result`** / **`error`** e può eseguire **al massimo un** `refreshCounts()` finale controllato (**D61-14**). |
| **`cancelInFlight()`** | Annulla **solo** il `Task` UI legato al drain (se supportato), **senza** cleanup/truncate outbox. Coerente con cancellazione TASK-060 / restore snapshot lato service. |
| **`selectedLimit`** | `Int` scelto da **preset UI** `{5, 10, 25}` — **default 10**. Controlla **solo** il **batch massimo** di tentativi `record` / entry da drenare in quella run (**parametro `limit`** di `drainOnce`). **Nessun** `TextField` / input libero; il ViewModel **non** accetta valori fuori preset. |
| **`lastCountsRefreshAt`** *(opzionale, naming EXECUTION)* | `Date?` aggiornato **solo** al **successo** di `refreshCounts()` — **ora dispositivo locale** al termine del fetch (`Date()`), **nessun** server time né dato remoto; alimenta copy **“Ultimo aggiornamento: HH:mm”** (**D61-21**, **§ 4.2**). Prima del **primo** refresh riuscito: `nil` (timestamp **non** mostrato **oppure** stato neutro *“Conteggi non ancora caricati”* — chiave **`counts.notLoaded`**). |

**`selectedLimit` vs `fetchScanLimit` (chiarezza)**

- **`selectedLimit`** = unico limite **esposto** in UI (preset **5 / 10 / 25**) → mappa su **`limit`** di `drainOnce`.
- **`fetchScanLimit`** resta **dettaglio interno** del `SyncEventOutboxDrainService` (default algoritmico TASK-060) **o** costante prudenziale fissata in EXECUTION nel wiring — **non** è una seconda manopola utente.
- La **UI** non espone `fetchScanLimit`; **nessun** input libero per scan limit (**T61-22**).

**Dipendenze iniettate (ENV / test):**

- `ModelContext` (o wrapper) per `SyncEventOutboxLocalStore`.
- Factory / closure **`makeDrainService()`** o equivalente che costruisce `SyncEventOutboxDrainService` con `SyncEventRecording` reale in app DEBUG.
- **`ownerUserID`** da sessione Supabase auth (pattern altre card DEBUG), allineato al guard UUID TASK-060 per `drainOnce`.
- In test: `drainOnce` stub o ViewModel con closure che simula outcome **senza** rete.

**Nota — `refreshCounts()` fallisce** (errore **locale**/store; **non** è esito `noWork` del drain):

- **Non** cancellare automaticamente gli **ultimi conteggi validi** già mostrati in UI.
- Mostrare **errore generico inline**, es.: *“Conteggi non aggiornati. Riprova.”* (`options.supabase.syncEventsOutbox.counts.refreshFailed` — **D61-22**).
- Mantenere **`lastCountsRefreshAt` precedente** se già valorizzato.
- Se **auth/owner** non sono più validi: **non** abilitare drain (né refresh) sulla base di conteggi **vecchi** — applicare le regole **§ Auth / owner state** / **D61-13** / **D61-23**.
- **Non** mappare questo fallimento a uno stato che equivalga a **“noWork”** sul drain; resta un errore di **lettura conteggi** distinto dall’outcome TASK-060.

### Auth / owner state

La futura UI DEBUG deve gestire **esplicitamente** sessione Supabase e validità **`ownerUserID`** (allineato al guard UUID TASK-060) **prima** di qualsiasi `fetchCounts` o `drainOnce`.

| Stato | UI |
|------|-----|
| **Sessione Supabase assente** | Messaggio generico localizzato: *“Sessione Supabase non disponibile”* (`options.supabase.syncEventsOutbox.auth.missing`). **Disabilitare** refresh conteggi **e** drain. |
| **ownerUserID assente o non UUID locale valido** | Messaggio generico: *“Owner locale non valido”* (`options.supabase.syncEventsOutbox.owner.invalid`). **Disabilitare** drain **e** refresh conteggi (nessuna lettura outbox senza owner valido). |
| **Auth presente ma conteggi non ancora caricati** | Stato **neutro**; CTA **“Aggiorna conteggi”** disponibile (se sessione **e** owner validi). |
| **Auth valida + retryable > 0** | Abilitare CTA drain (sempre con **conferma nativa** prima di `confirmDrain()`). |
| **Auth valida + retryable == 0** | Empty state positivo *“Nessun evento da drenare”*; CTA drain non invitante / disabilitata. |

**Regola:** se **`ownerUserID`** non è valido (o sessione assente), **non** chiamare `fetchCounts`, **`drainOnce`**, recorder live né RPC.

**Cambio sessione Supabase, account o `ownerUserID`:**

- Cancellare, se possibile, il **`Task` UI in-flight** (refresh o drain) legato al vecchio contesto.
- **Resettare** l’**ultimo risultato drain** (`result` / surface equivalente) — non mostrare esiti del drain precedente sotto il nuovo account.
- **Invalidare o azzerare** i **conteggi** mostrati se riferiti a un **owner diverso**: **non** mostrare conteggi del vecchio owner sotto il nuovo account (**D61-23**).
- **`lastCountsRefreshAt`**: azzerare o non applicare al nuovo owner finché non c’è un nuovo `refreshCounts()` riuscito per il **nuovo** `ownerUserID`.
- Richiedere un **nuovo** `refreshCounts()` (manuale o controllato su riapertura card) per il nuovo owner prima di considerare la UI aggiornata.

### 4.2 UI futura in `OptionsView`

**Collocazione e build**

- **Solo** `#if DEBUG`.
- **Card compatta** nella sezione **Avanzata / Supabase DEBUG** (ordine coerente con TASK-054: diagnostica read-only vs push — questa card è **locale + drain manuale**, non sostituisce sync catalogo completo).

**Titoli (tutti localizzati)**

- **Titolo:** “Outbox sync_events”
- **Sottotitolo:** “Drain manuale DEBUG degli eventi locali già registrati. Non parte automaticamente.”

**Conteggi**

- Dettagli in **`DisclosureGroup`** o sezione espandibile — **OptionsView resta pulita** a colasso.
- Mostrare **solo numeri** (label + valore), per bucket: **pending**, **retryable** (copy “ritentabili”), **blocked**, **dead** (copy “esauste”), **sent**, **localOnly**.
- **Timestamp locale privacy-safe** dopo un `refreshCounts()` **riuscito**: *“Ultimo aggiornamento: HH:mm”* (solo **ora locale** al termine del fetch — **`Date.now` dispositivo**; **nessun** orario server né dato remoto). Formattazione breve in EXECUTION (es. `DateFormatter` fuso **locale** scheda).
- Se i conteggi **non sono mai stati** caricati con successo: stato neutro *“Conteggi non ancora caricati”* (**`counts.notLoaded`**) **oppure** **non** mostrare riga timestamp (**D61-21**).
- Dopo un **drain** concluso, il **`refreshCounts()` finale controllato** (**D61-14**) può aggiornare **anche** questo timestamp (se il refresh finale ha successo).
- **Nessuna** lista di entry. **Nessun** payload raw. **Nessun** barcode, nome prodotto, supplier, category, UUID business in testo UI.

**Azioni**

| CTA | Ruolo | Conferma | Rete |
|-----|-------|----------|------|
| **Secondaria — “Aggiorna conteggi”** | Chiama **solo** `refreshCounts()` | **Non** richiesta | **No** |
| **Primaria — “Drena outbox sync_events”** | Dopo conferma nativa → `confirmDrain()` | **Obbligatoria** | **Sì** (via drain service) |

**Regole CTA primaria**

- Visibile o **abilitata** solo se **`retryable > 0`** (empty state: CTA non deve sembrare disponibile).
- **Disabilitata** durante **`draining`** (e opzionalmente durante `loadingCounts` se si vuole evitare race UX).
- Il tap sulla CTA **non** chiama subito `drainOnce`: apre **`confirmationDialog`** o **`alert`**; **solo** l’azione di conferma chiama `confirmDrain()`.

**Conferma nativa — copy proposto (localizzato, con placeholder N):**

> “Invierà fino a **N** eventi ritentabili a Supabase. Nessun dato verrà cancellato.”

dove **N** = `min(selectedLimit, retryable)` (o solo `selectedLimit` se si preferisce messaggio conservativo — da fissare in EXECUTION; **non** mostrare liste ID).

**Batch limit (UI)**

- **Preset** fissi **5 / 10 / 25** (picker segmentato o menu compatto).
- **Default 10**.
- Vietato campo testo libero; vietato passare al ViewModel valori **∉ {5, 10, 25}**.

**Feedback**

- Ultimo risultato drain **inline** nella card (testo breve + eventuale breakdown numerico).
- **Evitare** snackbar / toast come superficie **primaria**; allineamento alle altre card DEBUG (testo persistente nella card).

**Mappatura risultato — copy UX (privacy-safe)**

| Outcome / caso | Copy indicativa |
|----------------|-----------------|
| **noWork** | “Nessun evento ritentabile” |
| **drained** | “Inviati N eventi” (N da `sent` o `attempted` — definito in EXECUTION) |
| **partiallyDrained** | Breakdown **numerico**: `sent`, `retryScheduled`, `blocked`, `dead`, `remainingRetryable` (se valorizzato) |
| **blockedPayloadReplay** / **blocked** | Errore contract/block **generico**, **senza** payload |
| **alreadyRunning** | “Drain già in corso” |
| **networkFailed** | Errore rete **senza** URL/token |
| **cancelled** | “Annullato” |
| **invalidOwnerUserID** / **localSaveFailed** | Messaggi **generici** localizzati |

**Empty state (retryable == 0)**

- Stato **tranquillo**: “Nessun evento da drenare”.
- Resta disponibile **“Aggiorna conteggi”**; CTA drain **non** usabile / non invitante.

**Accessibilità**

- **VoiceOver**: label esplicite sulle CTA (“Aggiorna conteggi outbox”, “Drena outbox sync_events…”).
- Conteggi anche come **frasi** leggibili, es. “Ritentabili: 3”, non solo numeri isolati.
- **`loadingCounts`** / **`draining`**: stato **annunciabile** (es. `accessibilityHint` / progress associato).

**Coerenza SwiftUI / `OptionsView`**

- Componenti nativi coerenti con il resto della schermata: **`Section`**, **`GroupBox`** o pattern **card** già usato, **`DisclosureGroup`**, **`Button`**, **`Picker`** segmentato o **menu** compatto per il limite.
- **Evitare** layout custom pesanti.
- **Evitare** colori custom **nuovi** salvo quelli già usati dalle card DEBUG.
- **CTA primaria**: peso visivo chiaro ma **non** distruttivo — **non** usare stile **`destructive`**: il drain non cancella dati; messaggio di conferma già lo chiarisce.
- **Risultato inline**: testo **breve**; eventuali **dettagli numerici** (es. breakdown `partiallyDrained`) nell’area **espandibile**.

### 4.3 Privacy (obbligatorio)

- **No** `entity_ids` / `metadata` / payload raw in Text.
- **No** barcode, nome prodotto, supplier, category in stringhe UI.
- **No** UUID business o sessione in chiaro nella copy; riusare pattern altre card se già accettato — altrimenti omit.
- **Errori**: solo categorie / codici **redatti** o sanificati (`SyncEventOutboxPrivacySanitizer` dove applicabile).

### 4.4 Anti-regressioni architetturali

- Il ViewModel **non** importa `SupabaseClient` né chiama `.rpc` direttamente — solo **`SyncEventOutboxDrainService`** + **`SyncEventRecording`** (via service) + **`SyncEventOutboxLocalStore`**.
- **Nessun** timer, **nessun** `BGTask`, **nessun** Realtime, **nessun** worker.
- **`onAppear` / apertura card:** ammesso **solo** `refreshCounts()` **se** sessione **e** `ownerUserID` validi (**§ Auth / owner state**); **vietato** auto-`drainOnce`, auto-`record`, qualsiasi invio remoto implicito.
- **`refreshCounts()` da `onAppear`:** deve essere **controllato** ed **idempotente** lato UI — es. **una volta per mount** della card o quando l’utente **riapre** espandendo la card; **evitare** loop o refresh ripetuti a ogni ricalcolo SwiftUI / cambio stato **non** legato all’apertura.
- **Dopo** un drain concluso (`confirmDrain` terminato): ammesso **un solo** `refreshCounts()` finale controllato per riallineare i conteggi (non una raffica).

### 4.5 Non-goal UX/UI

La card DEBUG **non** deve diventare una dashboard complessa:

- **No** tabella **entry-by-entry** (né “righe” outbox navigabili).
- **No** grafici.
- **No** log viewer o console integrata.
- **No** colore custom **nuovo** (coerente anche con **D61-16** / card esistenti).
- **No** lista **payload** / JSON / `entity_ids` / `metadata` in chiaro.
- **No** azione **distruttiva** (delete/truncate) — fuori perimetro TASK-061.
- **No** **“retry all”** o azione parallela separata dal **drain controllato** con conferma (un solo percorso operativo per invio remoto).
- La UI resta allineata a **`OptionsView`**: **card compatta**, **dettagli espandibili**, **copy breve**, **azione primaria** chiara ma non aggressiva (**non** `destructive`).

### 4.6 Copy e chiavi localizzazione proposte

La futura **EXECUTION** deve usare chiavi sotto namespace coerente **`options.supabase.syncEventsOutbox.*`** (valori **IT** canonici sotto; tradurre **EN / ES / zh-Hans**, nessuna stringa utente hardcoded nella nuova card).

| Chiave proposta | IT canonico |
|-----------------|-------------|
| `options.supabase.syncEventsOutbox.title` | Outbox sync_events |
| `options.supabase.syncEventsOutbox.subtitle` | Drain manuale DEBUG degli eventi locali già registrati. Non parte automaticamente. |
| `options.supabase.syncEventsOutbox.refresh` | Aggiorna conteggi |
| `options.supabase.syncEventsOutbox.drain` | Drena outbox sync_events |
| `options.supabase.syncEventsOutbox.empty` | Nessun evento da drenare |
| `options.supabase.syncEventsOutbox.limit` | Limite |
| `options.supabase.syncEventsOutbox.confirm.title` | Conferma drain |
| `options.supabase.syncEventsOutbox.confirm.message` | Invierà fino a %d eventi ritentabili a Supabase. Nessun dato verrà cancellato. |
| `options.supabase.syncEventsOutbox.result.noWork` | Nessun evento ritentabile |
| `options.supabase.syncEventsOutbox.result.drained` | Inviati %d eventi |
| `options.supabase.syncEventsOutbox.result.alreadyRunning` | Drain già in corso |
| `options.supabase.syncEventsOutbox.result.cancelled` | Annullato |
| `options.supabase.syncEventsOutbox.result.network` | Errore di rete. Riprova più tardi. |
| `options.supabase.syncEventsOutbox.result.blocked` | Alcuni eventi sono bloccati dal contratto locale. |
| `options.supabase.syncEventsOutbox.auth.missing` | Sessione Supabase non disponibile |
| `options.supabase.syncEventsOutbox.owner.invalid` | Owner locale non valido |
| `options.supabase.syncEventsOutbox.count.pending` | In attesa: %d |
| `options.supabase.syncEventsOutbox.count.retryable` | Ritentabili: %d |
| `options.supabase.syncEventsOutbox.count.blocked` | Bloccati: %d |
| `options.supabase.syncEventsOutbox.count.dead` | Esausti: %d |
| `options.supabase.syncEventsOutbox.count.sent` | Inviati: %d |
| `options.supabase.syncEventsOutbox.count.localOnly` | Solo locali: %d |
| `options.supabase.syncEventsOutbox.loadingCounts` | Aggiornamento conteggi… |
| `options.supabase.syncEventsOutbox.draining` | Drain in corso… |
| `options.supabase.syncEventsOutbox.result.partial` | Inviati %d eventi. %d da ritentare, %d bloccati, %d esausti. |
| `options.supabase.syncEventsOutbox.result.localSaveFailed` | Salvataggio locale non riuscito. Riprova. |
| `options.supabase.syncEventsOutbox.result.invalidOwner` | Owner locale non valido |
| `options.supabase.syncEventsOutbox.accessibility.refresh` | Aggiorna conteggi outbox sync_events |
| `options.supabase.syncEventsOutbox.accessibility.drain` | Drena manualmente outbox sync_events |
| `options.supabase.syncEventsOutbox.accessibility.counts` | Conteggi outbox sync_events |
| `options.supabase.syncEventsOutbox.counts.notLoaded` | Conteggi non ancora caricati |
| `options.supabase.syncEventsOutbox.counts.lastUpdated` | Ultimo aggiornamento: %@ |
| `options.supabase.syncEventsOutbox.counts.refreshFailed` | Conteggi non aggiornati. Riprova. |

**Note (EXECUTION):**

- Coprire anche stringhe **partiallyDrained** / messaggi generici **save/owner** se non già coperte — mantenere **privacy-safe** e prefisso **`options.supabase.syncEventsOutbox.`** (la riga **`result.partial`** copre un breakdown sintetico; raffinare in review se ridondante con altre chiavi).
- Per **`result.partial`**, i placeholder IT canonici sono: **`sent`**, **`retryScheduled`** o **`remainingRetryable`** se disponibile e più corretto per la UI, **`blocked`**, **`dead`**. La futura **EXECUTION** deve **scegliere un solo significato** per il **secondo** numero e mantenerlo **coerente nei test**.
- Se alcune chiavi risultano **ridondanti** con chiavi **`options.supabase.*`** già esistenti, è **ammesso** il **reuse** solo se il copy resta **chiaro**, **privacy-safe** e presente in **IT / EN / ES / zh-Hans**; altrimenti mantenere chiavi dedicate sotto **`syncEventsOutbox`**.

---

## 5. Anti-scope obbligatorio (TASK-061 e futura EXECUTION vincolata)

- **No** auto-drain, **no** timer, **no** `BGTask`, **no** Realtime, **no** worker background.
- **No** cleanup outbox (**no** truncate/delete/reset/TTL massivo).
- **No** nuovo schema SwiftData / migration modello.
- **No** SQL, **no** Supabase migration, **no** modifica RPC, **no** `db push`.
- **No** codice Android.
- **No** nuovo push Product/ProductPrice / full sync automatico.
- **No** validazione live obbligatoria su dataset grande.
- **No** cambio policy **`changed_count > 1000`** (resta blocco contract lato app).
- **No** TASK-062 in questo turno.

**Copy e perimetro sync (anti-confusione)**

- La card **non** deve usare formulazioni tipo *“Sincronizza tutto”*, *“Sync completo”*, *“Aggiorna cloud”* o simili.
- La card opera **solo** sull’**outbox locale** sync_events / drain manuale DEBUG: **non** avvia pull catalogo, push catalogo, sync sessioni/`history_entries`, ProductPrice sync, né full database sync.

---

## 6. Test pianificati (EXECUTION futura — elenco contratto)

Matrice estesa: ViewModel fake, gate **onAppear** (solo `refreshCounts`, senza loop), auth/owner e **cambio owner**, **timestamp** `lastCountsRefreshAt`, **errore refresh** senza wipe conteggi validi, CTA **retryable == 0**, preset **5/10/25** (solo **`selectedLimit`**; **no** UI `fetchScanLimit`), **conferma** prima di `drainOnce`, accessibility, chiavi **Localizable** (loading/draining/partial/**counts.\***), **non-goal** dashboard, copy **outbox vs sync completo**, regressioni TASK-060 e grep anti-scope; handoff EXECUTION con **elenco file letti** (**T61-27**).

| ID | Scenario |
|----|----------|
| **T61-01** | ViewModel con **fake** `drain` / recording — **noWork**. |
| **T61-02** | Success **drained** — conteggi attesi su outcome finto. |
| **T61-03** | **Partial** / failure — messaggio UI model **privacy-safe** (assert **no** substring vietate: barcode-like, raw UUID, “http”). |
| **T61-04** | **Double tap** / reentrancy — mentre loading, secondo tap ignorato; drain service reale resta coperto da TASK-060. |
| **T61-05** | **Cancellation** — task annullato → stato coerente. |
| **T61-06** | **invalidOwnerUserID** — copy generica. |
| **T61-07** | Localizzazione — nuove chiavi presenti in **IT / EN / ES / zh-Hans**. |
| **T61-08** | Release: UI **assente** se compile senza `DEBUG` (condizione `#if DEBUG`). |
| **T61-09** | Regressioni — `SyncEventOutboxDrainServiceTests` **invariati** salvo refactors necessari al DI (minimo cambiamento). |
| **T61-10** | Grep anti-scope su nuovi file — **no** `BGTask`, `subscribe`, `Timer`, auto `drainOnce` da `onAppear`, **no** `delete`/`truncate` outbox. |
| **T61-11** | `refreshCounts()` su appear / card load **non** chiama `drainOnce` né recorder / RPC (spy sulle closure o mock). |
| **T61-12** | CTA drain nascosta o disabilitata quando `retryable == 0`; empty state “Nessun evento da drenare” verificato. |
| **T61-13** | Preset limite **5 / 10 / 25**: default **10**, nessun input libero, nessun valore fuori preset passato al path `drainOnce`. |
| **T61-14** | Conferma obbligatoria: tap CTA prepara solo dialog; `drainOnce` **solo** dopo azione **confirm** (test ViewModel o UI test dove disponibile). |
| **T61-15** | VoiceOver / **accessibility** label per conteggi e CTA principali (presenza stringhe o traits attesi). |
| **T61-16** | Copy UI distingue **“outbox sync_events”** / **drain manuale DEBUG** da **“sync completo”** catalogo/sessioni (assert su chiavi o stringhe canoniche localizzate). |
| **T61-17** | Auth/sessione/owner mancanti o **invalidi**: **nessuna** chiamata a `fetchCounts`, `drainOnce` o recorder; UI mostra messaggio generico e CTA disabilitate. |
| **T61-18** | `onAppear` ripetuto / aggiornamenti stato **non** generano **loop** di refresh; dopo drain al massimo **un** `refreshCounts()` finale controllato. |
| **T61-19** | Tutte le chiavi `options.supabase.syncEventsOutbox.*` necessarie sono presenti in **IT / EN / ES / zh-Hans**; grep su `OptionsView` (nuova card) evita stringhe utente hardcoded. |
| **T61-20** | Copy UI (chiavi) **non** contiene “sync completo”, “sincronizza tutto” o formule ambigue; la card cita esplicitamente **outbox sync_events** / **manuale DEBUG**. |
| **T61-21** | La nuova card **non** mostra liste entry, payload raw, log estesi o dashboard complessa; verifica **snapshot** / struttura UI dove disponibile. |
| **T61-22** | **Nessun** controllo UI per `fetchScanLimit`; il ViewModel accetta solo **`selectedLimit`** preset **5/10/25** e passa `fetchScanLimit: nil` (o costante interna documentata) a `drainOnce`. |
| **T61-23** | Stati **loading** / **draining** / **partial** / **accessibility** usano chiavi **`options.supabase.syncEventsOutbox.*`** e sono presenti in **IT / EN / ES / zh-Hans** (**D61-19**). |
| **T61-24** | Dopo `refreshCounts()` **riuscito** viene valorizzato **`lastCountsRefreshAt`** (solo ora locale); **prima** del primo refresh riuscito il timestamp **non** è mostrato **oppure** compare stato neutro **`counts.notLoaded`** (**D61-21**). |
| **T61-25** | `refreshCounts()` **fallito** mantiene **ultimi conteggi validi** e **`lastCountsRefreshAt` precedente** se esiste; mostra **`counts.refreshFailed`**; **non** invoca `drainOnce`/recorder; **non** mappa a stato tipo **noWork** drain (**D61-22**). |
| **T61-26** | **Cambio owner**/sessione durante o dopo refresh/drain: azzera/invalida conteggi e **`result`** del vecchio owner; UI **non** mostra dati **cross-owner** (**D61-23**). |
| **T61-27** | *(Check planning/handoff EXECUTION)* Handoff verso **Codex** deve **elencare i file iOS letti** (allineato a **D61-25**) e **dichiarare** disponibilità riferimento Android / clone Supabase locale se applicabile — **prima** di modificare Swift. |

---

## 7. Criteri di accettazione — **solo planning (questo turno)**

**Nota:** le checkbox **[x]** indicano che il **contenuto è stato documentato nel planning**, **non** che la futura **implementation** sia stata eseguita o validata in codice. La **validazione tecnica** resta nella futura **PLANNING REVIEW** / **EXECUTION**.

- [x] File task aggiornato con **integrazione UX/UI/safety** (separazione read-only vs drain, ViewModel, UI `OptionsView`, **UX61-xx**, **D61-06…25**, **§ 4.5**, test **T61-11…T61-27**, approccio e rischi).
- [x] Auth/sessione/owner state documentati (**§ Auth / owner state**, **D61-13**, cambio account **D61-23**).
- [x] Anti-loop **`onAppear`** / refresh post-drain documentato (**§ 4.4**, **D61-14**).
- [x] Copy canonico e namespace **`options.supabase.syncEventsOutbox.*`** proposti (**§ 4.6**, **D61-15**), incl. **`counts.notLoaded` / `lastUpdated` / `refreshFailed`**.
- [x] Decisioni **D61-13…D61-25** aggiunte; test **T61-17…T61-27** aggiunti.
- [x] Timestamp locale ultimo refresh conteggi documentato (**§ 4.2**, **D61-21**, **T61-24**).
- [x] Errore refresh conteggi documentato senza cancellare ultimi valori validi (**D61-22**, **T61-25**).
- [x] Cambio sessione/account/owner documentato (**D61-23**, **T61-26**).
- [x] **Planning Review Checklist** aggiunta (**§ prima di Execution**).
- [x] Handoff futura **EXECUTION** richiede **rilettura codice iOS reale** aggiornata (**D61-25**, **T61-27**).
- [x] `docs/MASTER-PLAN.md` **controllato** — già coerente (TASK-061 **ACTIVE / PLANNING**, Claude / Planner, TASK-060 ultimo DONE, nessuna execution / TASK-062); **nessuna modifica** richiesta in questo turno.
- [x] TASK-061 resta **ACTIVE / PLANNING**, **non DONE**; **nessun TASK-062**.
- [x] **TASK-060** resta **DONE / Chiusura**; **TASK-052** resta **BLOCKED / superseded**, **non DONE**.
- [x] **Nessun** file Swift; **nessun** `project.pbxproj`; **nessun** build; **nessun** XCTest eseguito; **nessuna** modifica Supabase / Android.

---

## Decisioni UX/UI (planning — UX61-xx)

| ID | Decisione UX/UI | Motivazione |
|----|-----------------|-------------|
| **UX61-01** | Card DEBUG compatta + dettagli espandibili. | `OptionsView` resta leggibile; diagnostica avanzata non domina la schermata. |
| **UX61-02** | Separare **“Aggiorna conteggi”** da **“Drena”**. | Riduce rischio di invio remoto accidentale. |
| **UX61-03** | Conferma nativa obbligatoria prima del drain. | Anche in DEBUG il tap causa chiamate remote. |
| **UX61-04** | Batch limit con preset **5 / 10 / 25**, default **10**. | Più sicuro ed efficiente di input libero. |
| **UX61-05** | Risultato ultimo drain **inline** nella card. | Migliore per diagnostica persistente rispetto a toast/snackbar. |
| **UX61-06** | Nessuna lista entry e nessun payload raw. | Privacy e UI più semplice. |
| **UX61-07** | Copy chiaro: **“manuale”**, **“DEBUG”**, **“non automatico”**. | Evita confusione con sync cloud completo o Realtime. |
| **UX61-08** | Stato empty **positivo** quando `retryable == 0`. | L’utente capisce che non c’è nulla da fare. |

---

## Decisioni (planning — D61-xx)

| ID | Decisione |
|----|-----------|
| **D61-01** | UI **solo** `#if DEBUG`; Release senza superficie nuova. |
| **D61-02** | Drain **solo** dopo **conferma nativa** e `confirmDrain()`; stato **`draining`** obbligatorio durante l’invio. |
| **D61-03** | Conteggi outbox via **`fetchCounts`** esistente — **no** nuova query schema SwiftData salvo emergenza documentata in review. |
| **D61-04** | “Exhausted” in copy UX = mapping chiaro a **`dead`** / **blocked** terminali, **non** nuovo enum persistenza. |
| **D61-05** | Recorder live ammesso **solo** come implementazione di `SyncEventRecording` dietro **`confirmDrain()`** — **no** bypass del boundary TASK-058. |
| **D61-06** | `refreshCounts()` read-only può partire **automaticamente** all’apertura della card **solo** se sessione e `ownerUserID` sono **validi**, e **solo** in modo **controllato/idempotente** (**D61-13**, **D61-14**); **drain mai** automatico. |
| **D61-07** | Drain **sempre** preceduto da **conferma nativa**, anche in DEBUG. |
| **D61-08** | Limite batch esposto **solo** come preset **5 / 10 / 25**, default **10**. |
| **D61-09** | UI risultato ultimo drain **inline** nella card; **evitare** snackbar come superficie **primaria**. |
| **D61-10** | Copy UX deve usare **“outbox sync_events”** e **“manuale DEBUG”**, **non** “sync completo”. |
| **D61-11** | Se `retryable == 0`, CTA drain **non** deve sembrare disponibile. |
| **D61-12** | Nessun nuovo componente grafico pesante: preferire **subview private** leggere dentro `OptionsView`, salvo review diversa. |
| **D61-13** | Auth/sessione/owner **non validi** bloccano **sia** refresh conteggi **sia** drain; la UI mostra **solo** messaggi generici localizzati. |
| **D61-14** | `refreshCounts()` automatico da `onAppear` deve essere **idempotente** e **non** generare loop UI; dopo drain è ammesso **un solo** refresh finale. |
| **D61-15** | Tutte le stringhe nuove devono usare namespace **`options.supabase.syncEventsOutbox.*`**; **vietate** stringhe UI hardcoded per la nuova card in `OptionsView`. |
| **D61-16** | UI nativa SwiftUI **leggera** e coerente con `OptionsView`; **nessun** layout custom pesante, **nessun** nuovo linguaggio visivo. |
| **D61-17** | La futura UI resta una **card DEBUG compatta**, non una **dashboard** / **log viewer**; diagnostiche avanzate richiedono **task separato**. |
| **D61-18** | **`fetchScanLimit`** **non** viene esposto in UI; la futura EXECUTION usa **default/cap prudenziale** del service (`nil` → default TASK-060) **o** costante interna documentata; **nessun** input libero per scan limit. |
| **D61-19** | Stringhe **loading** / **draining** / **partial** / **accessibility** devono essere **localizzate**; **evitare** fallback hardcoded anche per stati transitori. |
| **D61-20** | In caso di **dubbio UX**, preferire **subview private** leggera, **card compatta**, **meno azioni** e **copy più esplicito** (criteri conflitto in **Handoff**). |
| **D61-21** | La card può mostrare **“ultimo aggiornamento conteggi”** usando **solo** timestamp **locale** dopo `refreshCounts()` riuscito; **nessun** dato remoto o sensibile nel timestamp. |
| **D61-22** | Errore **refresh conteggi** **non** cancella gli ultimi conteggi validi; se auth/owner **non** validi le azioni restano bloccate; copy **generico inline** (**`counts.refreshFailed`**). |
| **D61-23** | Cambio **sessione/account/owner** invalida conteggi e risultato drain precedenti; la UI **non** deve mostrare stato outbox di un **owner diverso**. |
| **D61-24** | **Naming definitivo** dei nuovi file va confermato in **Planning Review**; **default:** ViewModel dedicato **`SyncEventOutboxDrainDebugViewModel.swift`** + **subview privata leggera** in `OptionsView.swift` (file separato solo se la card eccede la soglia di leggibilità). |
| **D61-25** | Prima della futura **EXECUTION** l’**esecutore** deve **rileggere** il **codice iOS reale** aggiornato (elenco in **Handoff**) e **dichiarare** eventuale **indisponibilità** Android; **nessuna** execution basata **solo** su memoria. |

---

## Planning (Claude)

### Analisi

TASK-060 ha chiuso il **motore** di drain; manca un **trigger** operativo per sviluppatori. La superficie DEBUG in `OptionsView` è già consolidata (TASK-054/051). Il rischio principale è **privacy**, **tap accidentale** su invio remoto, **scope creep** verso dashboard/log viewer e **confusione** con sync catalogo completo: il design separa **refresh conteggi locale** (ammesso su `onAppear` controllato) da **drain remoto** (solo dopo **conferma nativa** e **`selectedLimit`**; **`fetchScanLimit`** resta interno al service — **D61-18**).

### Approccio proposto

1. Aggiungere ViewModel leggero **`SyncEventOutboxDrainDebugViewModel`** + card DEBUG con pattern **requestID** e guard double-tap.
2. **Separare** nel ViewModel **refresh conteggi** (solo `fetchCounts` / `loadingCounts`) da **drain remoto manuale** (`draining` → `confirmDrain()` → `drainOnce` **solo** dopo conferma nativa).
3. Riusare **`SyncEventOutboxDrainService`** senza modificarne il contratto se possibile.
4. Integrare **card compatta** in `OptionsView`: dettagli espandibili (`DisclosureGroup`), preset limite **5 / 10 / 25** (default **10**), **conferma nativa** prima del drain, **risultato inline** (no toast primario).
5. Usare **solo** chiavi **`options.supabase.syncEventsOutbox.*`** in `Localizable.strings` (**IT / EN / ES / zh-Hans**), inclusi stati transitori e accessibility (**D61-15**, **D61-19**); nessuna stringa utente hardcoded nella nuova card.
6. In futura **EXECUTION**: XCTest isolati sul ViewModel con **fake** drain + controlli UI/scope (appear = solo refresh controllato, **no loop**, gate auth/owner, **cambio owner**, **timestamp** / errore refresh conteggi, CTA gating, conferma, preset **solo** `selectedLimit`, **no** UI `fetchScanLimit`, accessibility, copy, **non-goal** dashboard — **T61-21…T61-27**); handoff EXECUTION con **lettura codice reale** (**D61-25**).

### File da modificare *(futura EXECUTION — elenco indicativo)*

- I **nomi** dei nuovi file sono **indicativi**; il nome **definitivo** del ViewModel/subview va confermato in **Planning Review** per coerenza con il naming esistente (**D61-24**).
- **Preferenza attuale:** `SyncEventOutboxDrainDebugViewModel.swift` (+ test omonimo).
- Per la **view**: preferire **subview privata** dentro `OptionsView.swift` se resta **piccola**; **file Swift separato** per la card solo se il corpo diventasse **eccessivamente lungo** (soglia da fissare in review; principio: leggibilità `OptionsView`).
- Nuovo *(indicativo)*: `SyncEventOutboxDrainDebugViewModel.swift`.
- Touch: `OptionsView.swift` (solo blocchi `#if DEBUG`; subview private leggeri — **D61-12**, **D61-24**).
- Nuovo *(indicativo)*: `SyncEventOutboxDrainDebugViewModelTests.swift` *(o nome allineato in review)*.
- Touch: `Localizable.strings` ×4 lingue (incl. **`counts.*`**).

### Rischi identificati

| Rischio | Mitigazione |
|---------|-------------|
| Fuga di PII in errori | Solo codici/categorie sanificati; review grep su stringhe UI. |
| Doppio drain concorrente | Conferma nativa + CTA disabilitata durante **`draining`** / `loadingCounts`; guard ViewModel + `alreadyRunning` del service. |
| Confusione **retryable** vs **pending** | DisclosureGroup con frasi accessibili tipo “Ritentabili: N”; copy **UX61-07** / **D61-10**. |
| Tap accidentale su drain | Conferma nativa **obbligatoria** (**UX61-03**, **D61-07**) + CTA disabilitata durante loading. |
| UI DEBUG troppo pesante | Card compatta + dettagli espandibili (**UX61-01**); nessuna lista entry (**UX61-06**). |
| Confusione con sync completo | Copy e chiavi **D61-10**, **D61-15**, anti-scope **§5**; test **T61-16**, **T61-20**. |
| Sessione/owner non validi | **D61-13**; nessun `fetchCounts`/drain; messaggi generici; test **T61-17**. |
| Loop refresh su `onAppear` | **D61-14**; un refresh per mount / riapertura controllata; test **T61-18**. |
| Scope creep dashboard / log | **D61-17**, **§ 4.5**; test **T61-21**. |
| Esposizione `fetchScanLimit` in UI | **D61-18**; test **T61-22**. |
| Refresh conteggi fallito / stato incoerente | **D61-22**; test **T61-25**. |
| Conteggio “stale” dopo cambio account | **D61-23**; test **T61-26**. |
| Drift naming file vs convenzioni repo | **D61-24**; conferma in **Planning Review**. |
| EXECUTION senza rilettura codice | **D61-25**; check **T61-27**. |

### Handoff post-planning

- **Prossima fase**: **PLANNING REVIEW** — restare in **PLANNING**; **nessuna EXECUTION Swift automatica**; **nessun** build/Xcode test in questa fase documentale.
- **Prossimo agente**: **Claude / Reviewer** o **utente**.
- **Prima della futura EXECUTION**, il **reviewer** deve confermare **collocazione** della card:
  - **dentro** una card Supabase DEBUG già esistente; **oppure**
  - come **nuova subview privata** in `OptionsView`;
  - **Scelta consigliata:** **subview privata leggera** se evita di **gonfiare** eccessivamente `OptionsView` (**D61-12**, **D61-20**).
- **In caso di conflitto UX**, privilegiare sempre: **meno superficie visiva**; **copy più chiaro**; **meno azioni** disponibili; **nessun dato sensibile**; **coerenza** con le card DEBUG già presenti (**D61-20**).
- **Prima della futura EXECUTION**, l’**esecutore** deve **rileggere** (repo iOS aggiornata, **nessuna** execution “a memoria” — **D61-25**):
  - clone / workspace **iOS** allineato (es. Git locale allineato a `origin` o branch concordato);
  - `OptionsView.swift`;
  - `SupabaseSyncEventDebugViewModel.swift`;
  - `SyncEventOutboxDrainService.swift`;
  - `SyncEventOutboxEntry.swift`;
  - `SyncEventRecording.swift`;
  - `SupabaseSyncEventLiveRecorder.swift`;
  - localizzazioni **IT / EN / ES / zh-Hans**;
  - `docs/MASTER-PLAN.md`;
  - **questo file** `TASK-061`.
- **Android:** usare **solo** come riferimento **funzionale**; **non** copiare Kotlin; se esistono task Android pertinenti **localmente**, leggerli **prima** di EXECUTION; se il repo Android **non** è disponibile, **dichiararlo esplicitamente** nell’handoff EXECUTION (**T61-27**).
- **Prima di EXECUTION** validare: **D61-01…D61-25**, **UX61-01…UX61-08**, **T61-01…T61-27**, **Planning Review Checklist**, copy **Localizable** (`options.supabase.syncEventsOutbox.*`, incl. **`counts.*`**), **timestamp** refresh conteggi (**D61-21**), **errore refresh** (**D61-22**), **cambio auth/owner** (**D61-23**), **auth/owner** gating, **anti-loop** `onAppear`, **privacy** gate, **non-goal** §4.5, **`fetchScanLimit`** non in UI, **lettura codice iOS reale** aggiornata (**D61-25**), elenco file / naming (**§ File da modificare**, **D61-24**).
- **Solo dopo approvazione esplicita** (review + **conferma utente** per passaggio **PLANNING → EXECUTION**) si potrà passare a **EXECUTION** (**Codex**).
- **Non** creare **TASK-062**; **non** impostare **DONE** per TASK-061 da questo planning.
- **Planning freeze:** non espandere ulteriormente il task con **nuove feature** o **nuovi test** prima della **Review**; eventuali aggiunte devono essere motivate come **fix di coerenza**, non come **nuovo scope**.

**Stato:** **READY FOR PLANNING REVIEW** — **non** **READY FOR EXECUTION** finché la review non lo dichiara (e **anche** con review **APPROVED** resta necessaria **conferma esplicita utente** prima di EXECUTION — vedi checklist sotto).

---

## Planning Freeze

Questo planning è considerato **completo per Review**.

Da questo punto in poi evitare di aggiungere **nuove feature**, **nuovi stati UI** o **nuovi flussi**, salvo **correzioni di contraddizioni reali** trovate in review.

Sono ammessi **solo**:

- correzioni di **wording**;
- correzioni di **coerenza interna**;
- chiarimenti su **decisioni già esistenti**;
- **fix documentali** richiesti dalla **Planning Review**.

Non aggiungere altri ID **D61-xx**, **UX61-xx** o **T61-xx** salvo **esplicita richiesta del reviewer**, perché il task è già sufficientemente definito per la fase di **Planning Review**.

**Stato finale atteso:** **READY FOR PLANNING REVIEW** — **non** **READY FOR EXECUTION**.

---

## Planning Review Checklist

La **review di planning** deve dare uno dei tre esiti:

- **APPROVED** — il task può passare a **EXECUTION** **solo dopo conferma esplicita dell’utente** (non automaticamente alla sola approval).
- **CHANGES_REQUIRED** — restare in **PLANNING** o passare a **fix documentale**, **senza** Swift.
- **REJECTED** — rifare planning.

**Nota:** Anche con review **APPROVED**, **questo file non autorizza EXECUTION automatica**. Serve **conferma esplicita dell’utente** per passare da **PLANNING** a **EXECUTION**.

**Checklist reviewer:**

- [ ] **D61-01…D61-25** coerenti e non contraddittorie.
- [ ] **UX61-01…UX61-08** coerenti con `OptionsView`.
- [ ] **T61-01…T61-27** sufficienti ma non eccessivi.
- [ ] Anti-scope confermato: **no** auto-drain, **no** `BGTask`, **no** Realtime, **no** cleanup.
- [ ] UI DEBUG **non** diventa dashboard.
- [ ] Copy **Localizable** completo e **privacy-safe** (incl. **`counts.*`** / timestamp).
- [ ] Auth/owner e **cambio account** gestiti.
- [ ] **`selectedLimit`** e **`fetchScanLimit`** distinti.
- [ ] `onAppear` **non** genera loop.
- [ ] Handoff **EXECUTION** richiede **lettura codice reale** iOS (**D61-25**, **T61-27**).
- [ ] **TASK-061** resta **non DONE** fino a review + conferma utente post-implementazione (policy progetto).

---

## Execution (Codex)

### Avvio EXECUTION controllata — 2026-05-07

**User override operativo:** il file task era in **ACTIVE / PLANNING** e dichiarava necessaria review planning prima dell'execution. L'utente ha fornito conferma esplicita per passare a **ACTIVE / EXECUTION**. Impatto workflow: Codex procede solo con l'implementazione minima gia' definita da TASK-061; eventuali contraddizioni reali restano bloccanti; il task non puo' essere marcato DONE da Codex.

**Obiettivo compreso:** implementare una UI DEBUG minima in `OptionsView` per conteggi locali outbox `sync_events` e drain manuale on-demand tramite `SyncEventOutboxDrainService`, con `SyncEventRecording` dietro il service, conferma nativa, auth/owner gating, no auto-drain e no backend/schema nuovi.

**File letti prima di Swift:**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`
- `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md`
- `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseSyncEventDebugViewModel.swift`
- `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql` *(solo lettura, conferma contratto locale gia' indicato)*
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md` *(solo riferimento funzionale; nessun Kotlin copiato)*

**File previsti in modifica:**
- `iOSMerchandiseControl/SyncEventOutboxDrainDebugViewModel.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`
- `docs/MASTER-PLAN.md`

**Piano minimo:**
1. Aggiungere ViewModel `@MainActor` testabile con `requestID`, guard reentrancy, preset 5/10/25, refresh conteggi locale e drain solo da `confirmDrain()`.
2. Integrare card DEBUG compatta in `OptionsView` sotto `#if DEBUG`, con auth/owner gating, conteggi, timestamp, preset, CTA refresh e CTA drain con `confirmationDialog`.
3. Aggiungere localizzazioni dedicate `options.supabase.syncEventsOutbox.*`.
4. Aggiungere XCTest ViewModel/fake e localizzazione; eseguire build, test mirati/regressioni, `git diff --check` e grep anti-scope.

**Handoff iniziale:** EXECUTION in corso; TASK-061 resta **ACTIVE**, **non DONE**, nessun TASK-062.

### Completamento EXECUTION — 2026-05-07 15:19 -04

**File letti / controllati durante execution:**
- Documentazione obbligatoria: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`, `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`, `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`, `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md`, `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md`.
- Codice iOS: `OptionsView.swift`, `SupabaseSyncEventDebugViewModel.swift`, `SupabaseSyncEventPreviewService.swift`, `SyncEventOutboxDrainService.swift`, `SyncEventOutboxEntry.swift`, `SyncEventRecording.swift`, `SupabaseSyncEventLiveRecorder.swift`, `ContentView.swift`, `iOSMerchandiseControlApp.swift`.
- Localizzazioni: `it.lproj/Localizable.strings`, `en.lproj/Localizable.strings`, `es.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings`.
- Supabase locale solo lettura: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`.
- Android solo riferimento funzionale: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md`; nessun Kotlin copiato o modificato.

**File modificati:**
- `iOSMerchandiseControl/SyncEventOutboxDrainDebugViewModel.swift` *(nuovo)*.
- `iOSMerchandiseControl/OptionsView.swift`.
- `iOSMerchandiseControl/ContentView.swift`.
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`.
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift` *(solo `nonisolated static let` su costanti esistenti per warning actor-isolation, nessuna modifica API/behavior)*.
- `iOSMerchandiseControl/it.lproj/Localizable.strings`.
- `iOSMerchandiseControl/en.lproj/Localizable.strings`.
- `iOSMerchandiseControl/es.lproj/Localizable.strings`.
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`.
- `iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift` *(nuovo)*.
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`.
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`.
- `docs/MASTER-PLAN.md`.

**Cosa implementato:**
- ViewModel DEBUG `@MainActor` / `ObservableObject` con stati `idle`, `loadingCounts`, `draining`, `result`, `error`, pattern `requestID`, cancellazione task UI, guard reentrancy/double tap e reset su cambio sessione/owner.
- `refreshCounts()` locale-only tramite `SyncEventOutboxLocalStore.fetchCounts(ownerUserID:now:)`; non chiama drain, recorder, RPC o backend; mantiene ultimi conteggi/timestamp su failure e mostra errore generico.
- `confirmDrain()` come unico punto di chiamata a `SyncEventOutboxDrainService.drainOnce`; `selectedLimit` limitato ai preset 5/10/25 con default 10; `fetchScanLimit` passato `nil` per usare il default/cap interno del service.
- Card DEBUG compatta in `OptionsView` sotto `#if DEBUG`, in sezione Avanzata/Supabase DEBUG, con conteggi sintetici, `DisclosureGroup`, timestamp locale, CTA `Aggiorna conteggi`, CTA `Drena outbox sync_events` con `confirmationDialog`, auth/owner gating e risultati inline privacy-safe.
- Wiring DEBUG del `SupabaseSyncEventLiveRecorder` gia' esistente attraverso `iOSMerchandiseControlApp` -> `ContentView` -> `OptionsView`; il ViewModel non importa `SupabaseClient`, non usa `.rpc`, non accede direttamente al backend.
- Localizzazioni complete namespace `options.supabase.syncEventsOutbox.*` per IT / EN / ES / zh-Hans.
- XCTest puri con fake service/store/recorder equivalenti, senza rete e senza Supabase live.

**Cosa non implementato:**
- Nessun auto-drain, timer, BGTask, Realtime, worker, cleanup/delete/truncate/reset outbox.
- Nessuna dashboard, log viewer o lista entry.
- Nessun nuovo schema SwiftData, migration, SQL, Supabase `db push`, RPC change o accesso live diretto.
- Nessun Product/ProductPrice push, full sync, pull catalogo, history sync, Android code o TASK-062.
- Nessun test Simulator/manuale UI: non richiesto come obbligatorio dal task; copertura concentrata su ViewModel, build e controlli statici.

**Check eseguiti:**
- ✅ ESEGUITO — Build Debug simulatore: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> `** BUILD SUCCEEDED **`. Nota: resta warning Xcode preesistente AppIntents metadata "No AppIntents.framework dependency found".
- ✅ ESEGUITO — XCTest nuovi ViewModel: `SyncEventOutboxDrainDebugViewModelTests` -> `** TEST SUCCEEDED **`, 11 test passati.
- ✅ ESEGUITO — XCTest localizzazione TASK-061: `LocalizationCoverageTests/testTask061SyncEventsOutboxLocalizationKeysExistInSupportedLanguages` -> `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — Regressioni TASK-060: `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` -> `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — `plutil -lint` su IT / EN / ES / zh-Hans `Localizable.strings` -> OK.
- ✅ ESEGUITO — `git diff --check` -> nessun output, exit 0.
- ✅ ESEGUITO — grep anti-scope ViewModel: assenti `SupabaseClient`, `.rpc(`, `.channel`, `Realtime`, `BGTask`, `Timer`, `cleanup`, `truncate`, `record_sync_event`.
- ✅ ESEGUITO — grep anti-scope sui file modificati: assenti `BGTask`, `Timer`, `.channel`, `Realtime`, cleanup/truncate/deleteAll, auto-drain, `onAppear` con `drainOnce`, `.rpc(`. Primo grep ampio aveva falsi positivi su `truncated` gia' presente in `OptionsView`; rerun con boundary stretto PASS.
- ✅ ESEGUITO — copy anti-scope nel namespace TASK-061: assenti "Sincronizza tutto", "Sync completo", "Aggiorna cloud", "Full sync".
- ✅ ESEGUITO — Modifiche coerenti con planning e criteri di accettazione TASK-061: verificato staticamente e tramite test mirati.
- ⚠️ NON ESEGUIBILE — "Nessun warning nuovo introdotto" verificabile solo parzialmente da output build/test: dopo fix dei warning Swift introdotti durante il primo test, la build finale mostra solo il warning AppIntents metadata noto/preesistente; non e' stato eseguito un confronto storico automatico warning-by-warning.

**Risultati reali:**
- Feature compilata e testata su `iPhone 16e, iOS 26.2`.
- Nessuna rete o Supabase live usata nei test.
- Nessuna modifica a SQL, Supabase workspace, Android o schema.

**Limiti / rischi residui:**
- Verifica UI visuale su Simulator non eseguita: la build compila e la logica e' coperta da test, ma non c'e' screenshot/manual smoke della card in `OptionsView`.
- Il warning AppIntents metadata resta presente in build finale ma non e' introdotto dal perimetro TASK-061.
- Card DEBUG dipende da una sessione Supabase valida e da owner UUID; in assenza di recorder live configurabile il ViewModel mantiene drain disabilitato.

**Anti-scope confermato:**
- Confermati no auto-drain, no timer, no BGTask, no Realtime/channel, no worker, no cleanup outbox, no delete/truncate/reset, no nuovo schema, no SQL/migration/db push, no RPC change, no Product/ProductPrice push, no full sync/pull catalogo/history sync, no Android code, no TASK-062.

**Handoff post-execution a Review:**
- TASK-061 passa a **ACTIVE / REVIEW**.
- Responsabile attuale: **Claude / Reviewer**.
- TASK-061 **non** e' DONE; completamento finale resta subordinato a review e conferma utente.

---

## Review (Claude)

### Esito review tecnica severa — 2026-05-07 15:33 -04

**Esito:** **APPROVED_FIXED_DIRECTLY**.

**Sintesi review repo-grounded:** diff e file reali letti direttamente. Le modifiche TASK-061 risultano coerenti con lo scope: UI DEBUG manuale per outbox `sync_events`, refresh conteggi locale, drain manuale controllato, ViewModel testabile, localizzazioni e test. Non sono emersi problemi grossi, regressioni bloccanti, scope creep o codice inutile tale da richiedere loop FIX separato.

**Fix diretti applicati in review:**
- `SyncEventOutboxDrainDebugViewModel.swift`: compilazione del ViewModel sotto `#if DEBUG`; `confirmDrain()` ora richiede una conferma pendente e `canDrain` (`retryable > 0`, non busy, service disponibile) anche se chiamato programmaticamente.
- `iOSMerchandiseControlApp.swift`: il recorder live per il drain outbox viene costruito solo in `DEBUG`; in Release resta `nil`, senza call live automatica all'avvio.
- `SyncEventOutboxDrainDebugViewModelTests.swift`: aggiunti test piccoli per `confirmDrain()` senza conferma pendente e per retryable zero; aggiornato il path dei test drain validi per passare da `requestDrainConfirmation()`.

**File modificati durante review:**
- `iOSMerchandiseControl/SyncEventOutboxDrainDebugViewModel.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift`
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`
- `docs/MASTER-PLAN.md`

**Check eseguiti dopo review/fix:**
- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — XCTest ViewModel: `SyncEventOutboxDrainDebugViewModelTests` -> `** TEST SUCCEEDED **`, 13 test passati.
- ✅ ESEGUITO — XCTest localizzazioni: `LocalizationCoverageTests` -> `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — Regressioni TASK-060: `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` -> `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — `plutil -lint` IT / EN / ES / zh-Hans -> OK.
- ✅ ESEGUITO — duplicati chiavi localizzazione -> nessun duplicato rilevato.
- ✅ ESEGUITO — placeholder `%d` / `%@` TASK-061 tra IT / EN / ES / zh-Hans -> OK.
- ✅ ESEGUITO — grep anti-scope sui file TASK-061: nessun `BGTask`, `Timer`, `.channel`, `Realtime`, `deleteAll`, `record_sync_event`, `.rpc`; il grep ampio segnala solo falsi positivi `truncated` preesistenti nella UI ProductPrice di `OptionsView`.
- ✅ ESEGUITO — controllo ViewModel: nessun import `SupabaseClient`, nessuna `.rpc`, nessun accesso backend diretto.
- ✅ ESEGUITO — build Release extra: `xcodebuild ... -configuration Release ... build` -> `** BUILD SUCCEEDED **`; warning Swift 6 preesistente in `SupabaseProductPriceApplyService.swift:771` e warning AppIntents metadata non introdotti da TASK-061.
- ✅ ESEGUITO — `git diff --check` finale -> PASS.
- ⚠️ NON ESEGUIBILE — "Nessun warning nuovo introdotto" verificato per confronto qualitativo con output build: restano solo warning gia' noti/preesistenti, ma non e' stato eseguito un baseline warning-by-warning storico automatico.
- ❌ NON ESEGUITO — UI manuale/screenshot Simulator: non richiesto esplicitamente dal task; rischio residuo documentato.

**Anti-scope confermato:** nessun auto-drain, timer, BGTask, Realtime/channel, worker, cleanup/delete/truncate/reset outbox, nuovo schema SwiftData, SQL/migration/db push, modifica RPC, Product/ProductPrice push, full sync, pull catalogo, history sync, Android, TASK-062.

**Rischi residui:** nessuna evidenza visuale/manuale della card in Simulator; warning AppIntents metadata e warning Swift 6 Release in `SupabaseProductPriceApplyService.swift:771` sono preesistenti e fuori perimetro.

**Chiusura:** con conferma esplicita utente ricevuta per chiusura in caso di APPROVED / APPROVED_FIXED_DIRECTLY, **TASK-061 passa a DONE / Chiusura**. Workspace **IDLE**, nessun task attivo, **nessun TASK-062**.

---

## Fix (Codex)

*(Nessun loop FIX separato. I fix piccoli/medi autorizzati sono stati applicati direttamente in Review e documentati sopra come APPROVED_FIXED_DIRECTLY.)*

---

## Riferimenti codice (estratti citati)

Outcome drain (TASK-060):

```4:43:iOSMerchandiseControl/SyncEventOutboxDrainService.swift
nonisolated enum SyncEventOutboxDrainStatus: String, Sendable, Equatable {
    case noWork
    case alreadyRunning
    case drained
    case partiallyDrained
    case blockedPayloadReplay
    case blocked
    case networkFailed
}

nonisolated struct SyncEventOutboxDrainOutcome: Sendable, Equatable {
    let status: SyncEventOutboxDrainStatus
    let attempted: Int
    let sent: Int
    let retryScheduled: Int
    let blocked: Int
    let dead: Int
    let skippedIneligible: Int
    let remainingRetryable: Int?
    // ...
}
```

Conteggi outbox (store esistente — **nessun** nuovo schema):

```12:18:iOSMerchandiseControl/SyncEventOutboxEntry.swift
nonisolated struct SyncEventOutboxCounts: Sendable, Equatable {
    var pending: Int = 0
    var retryable: Int = 0
    var blocked: Int = 0
    var dead: Int = 0
    var sent: Int = 0
    var localOnly: Int = 0
}
```

RPC Supabase (fonte locale):

```69:81:/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql
create or replace function public.record_sync_event(
  p_domain text,
  p_event_type text,
  p_changed_count integer default 0,
  p_entity_ids jsonb default null,
  p_store_id uuid default null,
  p_source text default null,
  p_source_device_id text default null,
  p_batch_id uuid default null,
  p_client_event_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns public.sync_events
```

*(Percorso migration letto sul clone locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`.)*
