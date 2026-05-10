# TASK-093 — Local change accumulation / dirty set iOS

## Informazioni generali

- **Task ID:** TASK-093
- **Titolo:** Local change accumulation / dirty set iOS
- **File task:** `docs/TASKS/TASK-093-local-change-accumulation-ios.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura — REVIEW PASS**
- **Responsabile attuale:** **Nessuno — task chiuso**
- **Data creazione:** 2026-05-09
- **Ultimo aggiornamento:** 2026-05-09 23:15 -0400 — REVIEW completa con fix mirati e verifiche finali **PASS**; **TASK-093 DONE / Chiusura — REVIEW PASS** su override esplicito utente; TASK-094+ non aperti.
- **Ultimo agente che ha operato:** CODEX

---

## Dipendenze

- **Dipende da:** **TASK-092 DONE / Chiusura — REVIEW PASS** (`docs/TASKS/TASK-092-lightweight-auto-pull-foreground-ios.md`) — auto pull/check foreground iOS-first leggero sopra TASK-091; **TASK-091 DONE / Chiusura — REVIEW PASS** — MVP semi-auto Release (preview bounded, review prima di apply/push/drain).
- **Sblocca:** **TASK-094** (push intelligente aggregato **non** in questo task); **TASK-095** (lifecycle/background); **TASK-096** (acceptance finale) — **tutti restano TODO / Planning fino a handoff esplicito successivo**.

---

## 1. Obiettivo

Pianificare un **modello iOS-native** per **accumulare in locale** le modifiche al catalogo, ai prezzi e ai segnali coerenti con la roadmap sync (`dirty set` / **coda di intenzione**), in modo **bounded**, **deduplicato**, **retry-safe** (semantica locale) e **privacy-safe**, **senza** abilitare in TASK-093 il **push intelligente** né drain/apply automatici.

Preparare contratti, stati e handoff verso **TASK-094**, mantenendo **SwiftData** come cache/source operativa locale e **Supabase** come backend condiviso **futuro** (solo schema/contratto **read-only** in planning).

Decisione planning da usare come default se in futura review non emergono controindicazioni: **TASK-093 deve privilegiare un MVP piccolo e utile**, centrato su **catalogo locale + ProductPrice + import confermato**, evitando di trasformare ogni `HistoryEntry`, ogni cella della griglia Excel o ogni aggiustamento inventario in payload pending persistente. L'obiettivo è creare una base affidabile per TASK-094, non una coda universale troppo costosa.

Regola UX/architetturale aggiuntiva: il pending locale deve nascere solo da **azioni confermate e persistite** (salva prodotto, conferma import, salva prezzo, applica modifica database), non da ogni battitura in un form o da stati temporanei di sheet/dialog. In termini Compose/Room: non vogliamo un evento dirty per ogni `TextField` change, ma un record intenzionale quando la modifica diventa transazione locale valida.

---

## 2. Stato attuale iOS da verificare in repo (planning — non audit esaustivo)

*Verifica in **futura EXECUTION**; qui solo ipotesi repo-grounded da incrociare con il codice.*

- **Catalogo SwiftData (`Product`, `Supplier`, `ProductCategory`):** CRUD e import database in `DatabaseView` / flussi collegati; modifiche manuali non producono oggi, da soli, un **dirty set unificato** esposto alla Release beyond ciò che già inferiscono snapshot pending/outbox.
- **Prezzi (`ProductPrice`, campi prezzo su `Product`):** apply/pull/push guidati in perimetro **TASK-080+**; identità post-push **TASK-088**; accumulatori locali **non** obbligatoriamente collegati a ogni **edit** incrementale fuori dal flusso Release.
- **Import Excel / pre-generazione / inventario (`ExcelSessionViewModel`, `GeneratedView`, `PreGenerateView`):** grandi superfici di edit; oggi la persistenza è principalmente **modelli di dominio + `HistoryEntry`** — serve capire dove **registrare** “intento di sync” senza duplicare tutta la griglia in payload.
- **Sync inventario (`InventorySyncService`): applica conteggi allo stock** — potenziale fonte di “modifica locale” da classificare rispetto a cloud push.
- **Release / manual sync (`SupabaseManualSyncViewModel`, coordinator, push/pull services):** flussi **guidati** con piani volatili e conferme; **TASK-057** ha già **enqueue outbox** `sync_events` su **outcome terminali** di push manuale — **non** sostituisce un dirty set completo su **ogni** edit incrementale.
- **Outbox `SyncEventOutboxEntry` + servizi (`SyncEventOutboxEnqueueService`, `SyncEventRecording`, drain DEBUG/Release per **TASK-081):** stato macchina, payload JSON, limiti `changed_count`, idempotenza `clientEventId` — **base** per telemetria/registrazione cloud, da **distinguere** da “modifiche prodotto non ancora inviate” se il modello lo richiede.
- **Foreground semi-auto TASK-091/092:** suggerisce check read-only; **nessun** obbligo di nuova automazione in TASK-093.

---

## 3. Riferimento Android (solo funzionale — nessun porting 1:1)

Usare il repo Android **solo** come ispirazione per:

- **Dirty set / outbox:** batch, head-of-line, retry, coalescing per chiave logica (es. barcode / product id).
- **Segnali `sync_events` incrementali vs bulk** (documentati in task storici TASK-045 / TASK-068 / TASK-070 area).
- **Policy “bounded”** su dimensione payload e conteggi.

**Vincolo:** niente WorkManager BGTask-equivalente obbligatorio in TASK-093; niente adozione strutturale Kotlin/SQL.

---

## 4. Riferimento Supabase (read-only — schema/contratto)

Solo dove serve ancorare semantica (clone documentale / migration lette in task precedenti, **no** write live in TASK-093):

- Tabelle **catalogo** con `owner_user_id`, `updated_at`, tombstone `deleted_at` (**TASK-082, TASK-086**).
- **`inventory_product_prices`** con vincoli su `effective_at`, identità righe (**TASK-050+, TASK-071** area contratto).
- **`sync_events` / RPC `record_sync_event`:** `changed_count` 0…1000, shape `entity_ids` / `metadata`, idempotenza `client_event_id` (**TASK-055…059, TASK-071**).

Scopo: allineare **stati locali** (pending / sent / stale / non registrabile) al **contratto** remoto **futuro**, non modificare RLS/DDL.

---

## 5. Differenze / gap attesi

| Area | Oggi (atteso) | Dopo TASK-094+ (fuori scope TASK-093) |
|------|----------------|----------------------------------------|
| Modifica singola in Database | Salvataggio SwiftData immediato | Invio cloud può essere **ritardato** / batch |
| Outbox `sync_events` | Enqueue principalmente su path **push/apply confermati** | TASK-093 può introdurre **mirror concettuale** “dirty catalog” separato o estensione controllata — da decidere in planning review |
| ProductPrice multi-edit | Storico locale + push manuale | Accumulo **coalescing** per chiave `(product, type, effective_at)` o policy esplicita |
| Inventario / History | JSON in `HistoryEntry` | Classificare se “syncabile” vs **solo locale** |
| Baseline / stale | Guard in Release | Dirty record deve **invalidarsi** se baseline/owner/session cambia (**stale baseline**) |
| Privacy | Summary aggregati in Release | Dirty payload: **no** liste massicce di nomi/barcode in log; riferimenti opzionali **minimi** |
| Performance | Snapshot/piani bounded già presenti nei task sync | Dirty snapshot deve evitare full reload, N+1 query e main-thread work su dataset grandi |
| UX Release | Card/banner già mostrano check e stati cloud | Nuovo stato “modifiche locali in attesa” deve integrarsi senza duplicare CTA o creare doppia urgenza |
| Draft vs committed edit | Sheet/dialog possono avere stato temporaneo | Pending locale deve nascere solo dopo conferma/salvataggio, non durante la digitazione |
| Concorrenza | Multi-scene/foreground già gestiti nei task recenti | Pending snapshot/enqueue deve essere serializzato o idempotente per evitare doppie righe |
| Accessibilità / localizzazione | Release UI già localizzata e testata nei task precedenti | Copy futuro deve restare breve, localizzabile e compatibile con Dynamic Type/VoiceOver |
| Delete / tombstone | Catalogo remoto usa tombstone; locale può avere delete immediato | Pending delete deve essere esplicito e fail-closed se manca contesto remoto/local identity |
| Snapshot verso TASK-094 | Release ha piani volatili per preview/push | TASK-093 deve definire snapshot locale read-only, bounded e consumabile senza rete |
| Riconciliazione post-pull | Pull/apply può cambiare lo stato locale | Pending locale deve diventare stale/blocked/superseded se la base remota appena applicata rende il pending non sicuro |
| Indici/query SwiftData | Query attuali dipendono dai modelli esistenti | Pending store deve avere chiavi filtrabili (`status`, `entityKind`, `logicalKey`, `updatedAt`) per evitare full scan |

---

## 6. Cosa cambia per l’utente in futuro (post catena 093→094, non promesso in TASK-093)

- Indicazioni chiare in **Release** del tipo: “**Hai modifiche locali in attesa**” / “**Alcune modifiche non possono essere inviate automaticamente**”, con tono operativo e non tecnico. La UI futura deve restare coerente con lo stile iOS già usato: una card compatta, una CTA primaria quando serve, summary aggregati e dettagli solo dietro espansione/sheet.
- Riduzione passaggi manuali quando TASK-094 abiliterà push aggregato **con conferma** dove richiesta.
- Migliore **recovery** dopo crash: stato “pending” ricostruibile con limiti documentati.
- UX più prevedibile: se esistono sia modifiche remote da rivedere sia modifiche locali in attesa, la priorità visuale deve seguire l’ordine già stabilito nei task precedenti: **prima aggiornare questo dispositivo quando necessario**, poi proporre invio modifiche locali in TASK-094.
- Se ci sono alternative equivalenti di UI/UX, scegliere autonomamente l’opzione più nativa iOS e coerente con la UI esistente: meno pulsanti permanenti, più disclosure progressiva, `confirmationDialog` solo per mutazioni/scarti, `ProgressView` per operazioni lunghe, stati vuoti/errori recuperabili leggibili.
- Accessibilità preservata: summary breve, conteggi leggibili da VoiceOver, nessuna lista enorme in card, supporto Dynamic Type tramite layout adattivo e dettaglio in sheet quando serve.

Nessun claim **production-ready** globale da questo file.

---

## 7. Cosa NON cambia funzionalmente in TASK-093

- Nessuna nuova **sync automatica**, `Timer`, `BGTask`, Realtime, polling worker, drain/push/apply **automatico**.
- Nessun **push intelligente** aggregato (è **TASK-094**).
- Nessuna modifica **Kotlin/Android**, **SQL/migration/RLS** live, **write Supabase** da questo task.
- SwiftData resta **source operativa** locale; niente migrazione forzata a “cloud-first”.
- **TASK-094, TASK-095, TASK-096** **non** vengono aperti né pianificati in dettaglio operativo qui.

---

## 8. File iOS candidati da leggere in futura EXECUTION

*Elenco indicativo — affinare in EXECUTION.*

- Modelli / container: `iOSMerchandiseControl/Models.swift`, `iOSMerchandiseControlApp.swift`
- Persistenza pending locale: nuovo modello SwiftData candidato `LocalPendingChange`/`PendingLocalChange`, eventuale store/service dedicato, eventuali migration impact sul container SwiftData da verificare prima di patch
- Snapshot / presenter pending: nuovo service candidato `LocalPendingChangeSnapshotProvider` o estensione controllata di `SupabaseManualSyncLocalPendingSnapshotProvider`, con contratto read-only e fakeable per test
- Release / sync manuale: `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift`, `SupabaseManualSyncSemiAutomaticPolicy.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncLocalPendingSnapshotProvider.swift`, eventuali presenter/banner foreground TASK-092
- Push / pull / prezzi: `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseProductPriceApplyService.swift`, eventuali service ProductPrice push apply
- Outbox / eventi: `SyncEventOutboxEntry.swift`, `SyncEventOutboxState.swift`, `SyncEventOutboxLocalStore.swift`, `SyncEventOutboxEnqueueService.swift`, `SyncEventOutboxDrainService.swift`, `SyncEventRecording.swift`, `SupabaseSyncEventLiveRecorder.swift` *(se presente)*
- UI entry: `OptionsView.swift`, `ContentView.swift`
- CRUD / import: `DatabaseView.swift`, `ProductImportViewModel.swift` *(path esatto da verificare)*, servizi import/export database, apply import e punti in cui una modifica locale diventa persistente
- Inventario / Excel: `ExcelSessionViewModel.swift`, `GeneratedView.swift`, `PreGenerateView.swift`, `InventorySyncService.swift` *(path esatto da verificare)*

---

## 9. Micro-slice proposte

### S93-A — Inventario repo-grounded: local changes / outbox / sync events

Mappare **tutte** le superfici che oggi possono mutare SwiftData o produrre segnali sync; classificare: **A)** edit catalogo/prezzo diretto **B)** import confermato **C)** inventario **D)** enqueue outbox esistente **E)** nessun segnale. Output: tabella READY/PARTIAL/MISSING e decisione esplicita su cosa entra nel MVP.

### S93-B — Definizione dirty set locale catalogo

Decisione preferita da validare in review: proporre un **nuovo modello SwiftData leggero** tipo `LocalPendingChange` / `PendingLocalChange` invece di aggiungere molti flag a `Product`, `Supplier`, `ProductCategory` o `ProductPrice`. Il record deve contenere chiave stabile, `operation`, `entityKind`, stato, timestamp, `baselineFingerprint` opzionale e riferimenti minimi; il payload deve essere derivabile dal modello locale al momento dello snapshot quando possibile. Alternative ammesse solo se la lettura codice dimostra che un modello nuovo crea più regressioni che benefici.

### S93-C — Dedupe, batch identity, limiti dataset

Regole: coalescing per `barcode` / `product remoteID`, cap righe/logical ops, policy **split** se > soglia contratto `changed_count`; **clientEventId** generation e collisioni locali. La futura implementazione deve evitare full scan a ogni render: usare snapshot espliciti, query filtrate per stato, mappe in memoria costruite una volta per operazione e aggiornamenti incrementali dove possibile.

### S93-D — ProductPrice accumulation policy

Allineare a chiave logica Supabase (`owner + product + type + effective_at`), gestione **edit multipli** sulla stessa chiave, conflitto con stato “già inviato ma stale”, integrazione con **remoteID** post-TASK-088. ProductPrice entra nel MVP solo come intenzione logica bounded, non come duplicazione di tutto lo storico prezzi.

### S93-E — UX stati Release per “modifiche locali in attesa”

Solo **planning**: stati presentazionali (conteggi aggregati, **no** jargon raw), interazione con banner TASK-092 e card Release; **stringhe** in execution separata se approvate. La UI deve restare leggibile con Dynamic Type, VoiceOver e localizzazioni lunghe.

### S93-F — Test / fakeability / recovery / cancel / retry

Strategia XCTest: clock iniettabile, store in-memory, scenari cancel tra edit e futuro push; **recovery** dopo crash (best-effort); **retry** semantica **locale** (marcatura failed → pending). Aggiungere anche casi su commit boundary, coalescing, delete/tombstone e reentrancy.

### S93-G — Handoff verso TASK-094

Deliverable: interfaccia “**consumatore**” del dirty set (**snapshot bounded** per push plan) + invarianti pre-write (auth/owner/baseline) che TASK-094 deve rispettare; elenco esplicito **out of scope** per TASK-094.

### S93-H — UX/UI + efficienza del pending locale

Definire come il pending locale deve comparire nella card Release senza aggiungere rumore: conteggio sintetico, severità chiara, nessun doppio banner con TASK-092, CTA futura solo quando TASK-094 sarà disponibile. Stabilire anche regole di performance: niente query pesanti nel body SwiftUI, niente sorting/formatting costoso sul main thread per dataset grandi, niente duplicazione massiva di payload Excel/History nel dirty store.

### S93-I — State machine, cleanup e atomicità locale

Definire una state machine minima e testabile per il pending locale: `pending`, `superseded`, `blocked`, `staleBaseline`, `sent`/`acknowledged` — nome finale da validare in execution. La futura implementazione deve garantire che salvataggio del dato locale e registrazione del pending avvengano nello stesso flusso logico/transaction boundary dove possibile; se non possibile, documentare recovery e riconciliazione. Definire anche policy di cleanup bounded: coalescing, retention dei record inviati, cap record e fallback user-facing quando il limite viene raggiunto.

### S93-J — Commit boundary, coalescing e reentrancy

Definire con precisione i punti in cui una modifica diventa pending: salvataggio confermato di prodotto/fornitore/categoria, conferma import, inserimento prezzo/storico prezzo, eventuale delete/tombstone confermato. Escludere stati temporanei di form, sheet e griglie prima della conferma. Stabilire regole di coalescing deterministiche: create+update diventa create aggiornata; update+update mantiene ultima intenzione/field-set compatto; update+delete diventa delete; create+delete può diventare no-op locale se non ha mai avuto remoteID; ProductPrice coalescing resta per chiave logica `(product, type, effectiveAt)`. Definire infine reentrancy/idempotenza per import multipli, edit rapidi e multi-scene: stessa logical key + operation compatibile non deve generare duplicati non necessari.

### S93-K — Delete/tombstone e inventario fuori MVP

Definire esplicitamente la semantica delete: delete locale con `remoteID` noto deve diventare intenzione `delete`/tombstone; delete locale senza identità remota può diventare no-op/superseded se il record non è mai stato inviato; casi ambigui devono essere `blocked` o `staleBaseline`, mai pushati in modo distruttivo. Gli aggiustamenti inventario restano fuori MVP salvo evidenza forte in S93-A; al massimo vanno classificati come futura estensione con cap e UX separata.

### S93-L — Snapshot API verso TASK-094 e Release card

Definire un contratto read-only e fakeable per ottenere uno snapshot bounded del pending locale senza rete: totale pending, conteggi per entityKind/status/severity, flag `isCapped`, `requiresCloudCheck`, `hasBlockedItems`, `hasStaleBaseline`, timestamp ultimo aggiornamento locale e indicazione UX primaria. Questo snapshot deve servire sia alla card Release sia al futuro push plan di TASK-094, ma in TASK-093 non deve inviare nulla al cloud.

### S93-M — Riconciliazione dopo pull remoto / baseline refresh

Definire cosa succede ai pending locali quando un pull/apply remoto cambia la base locale: se la modifica remota tocca la stessa logical key, il pending deve essere marcato `staleBaseline` o `blocked` finché l’utente non ricontrolla; se il pending è diventato identico allo stato remoto può diventare `superseded`; se è indipendente resta `pending`. Nessuna riconciliazione deve cancellare silenziosamente modifiche utente senza una regola documentata.

### S93-N — Indici/query e performance budget

Definire campi e query candidati per SwiftData prima della patch: filtro primario per `status`, `entityKind`, `logicalKey`, `updatedAt`; ordinamento stabile per snapshot; cap configurabile per evitare full scan. Budget planning: snapshot UI deve essere O(numero pending rilevanti), non O(tutti i prodotti/tutta la history), e deve poter essere calcolato fuori dal body SwiftUI.

---

## 9.1 Schema minimo candidato LocalPendingChange / PendingLocalChange

Solo planning: nomi e tipi reali da verificare in futura execution dopo lettura codice SwiftData.

Campi minimi candidati:

- `id`: UUID locale stabile.
- `schemaVersion`: versione locale del pending record per migration future.
- `entityKind`: product / supplier / category / productPrice; `inventoryAdjustment` resta fuori MVP salvo decisione esplicita.
- `entityLocalID`: riferimento locale quando stabile e sicuro.
- `entityRemoteID`: opzionale, se già noto.
- `logicalKey`: chiave privacy-safe e dedupe-friendly; esempio hash o chiave normalizzata interna, non barcode in chiaro nei log.
- `operation`: create / update / delete / priceUpsert; `inventoryAdjust` solo se approvato fuori MVP.
- `status`: pending / superseded / blocked / staleBaseline / sent-or-acknowledged.
- `origin`: manualEdit / importConfirmed / priceEdit / releaseRecovery *(set finale da validare)*.
- `createdAt`, `updatedAt`, `lastAttemptAt`: timestamp locali.
- `baselineFingerprint`: opzionale, per bloccare push se la base cloud è cambiata.
- `clientEventID`: opzionale ma stabile quando il pending diventa consumabile da TASK-094.
- `changedFields`: set compatto opzionale, non payload massivo.
- `metadataSummary`: solo conteggi o note privacy-safe; niente dump di righe Excel.
- `severity`: info / warning / blocked *(derivabile o persistito solo se utile)* per presenter Release.
- `supersededBy`: opzionale, riferimento locale a record successivo quando il coalescing non elimina fisicamente il record.
- `lastKnownRemoteFingerprint`: opzionale, per distinguere baseline nota da baseline diventata stale dopo pull remoto.

**Decisione consigliata:** salvare nel pending intenzione + chiave logica + stato, non una copia completa del prodotto. Il payload completo per TASK-094 va derivato dai modelli SwiftData correnti al momento dello snapshot, così si evita duplicazione, si riduce storage e si coalescono meglio gli edit multipli.

---

## 9.2 UX/UI Release candidata

La UI futura deve essere piccola e coerente con la Release card esistente:

- Stato compatto: “Modifiche locali in attesa” + conteggio aggregato.
- Dettaglio opzionale in disclosure/sheet: prodotti, prezzi, elementi bloccati, elementi da ricontrollare; usare solo conteggi, non liste lunghe.
- Nessuna CTA di push in TASK-093. In TASK-094 la CTA potrà diventare “Invia modifiche al cloud” solo dopo review/check.
- Se esistono remote changes e local pending insieme, ordinare le azioni così: “Aggiorna questo dispositivo” prima, “Invia modifiche al cloud” dopo.
- Empty state: se non ci sono pending, non mostrare card extra; al massimo summary neutro dentro la card Release esistente.
- Error/recovery: usare copy non tecnico: “Da ricontrollare”, “Non inviabili ora”, “Richiede nuovo controllo”, evitando “dirty”, “baseline”, “outbox”.
- Accessibilità: summary breve leggibile da VoiceOver, conteggi con label chiara, layout stabile con Dynamic Type, niente overflow obbligatorio nella card.
- Localizzazione: evitare frasi lunghe o tecniche; preparare chiavi localizzabili in execution solo se il task passa a codice.

---

## 9.3 Regole di coalescing candidate

| Sequenza locale | Pending finale candidato | Nota |
|-----------------|--------------------------|------|
| create → update stesso prodotto | `create` con dati correnti derivati dal modello locale | Evita inviare due intenzioni quando il record non esiste ancora sul cloud |
| update → update stessa chiave | `update` unico con `changedFields` compatto | Last-write locale, payload derivato al momento snapshot |
| update → delete | `delete` / tombstone se supportato | Fail-closed se manca contesto remoto sufficiente |
| create locale mai inviato → delete | no-op o `superseded` | Non serve pushare un record mai esistito sul cloud |
| priceUpsert stessa `(product,type,effectiveAt)` | un solo `priceUpsert` | Rispetta identità ProductPrice e riduce duplicati |
| import confermato con N righe | batch logical keys + cap | Non salvare griglia completa nel pending store |
| inventario/stock adjustment | fuori MVP / `blocked` | Da non mischiare al catalog push senza task dedicato |

Queste regole sono candidate: in futura execution vanno validate contro i modelli reali iOS e contro la semantica Supabase già definita nei task precedenti.

---

## 9.4 Check di review planning prima dell'Execution

Prima di promuovere TASK-093 a EXECUTION, il reviewer deve verificare almeno:

- Il file resta planning-only e non promette push automatico.
- Il MVP è ancora piccolo: catalogo CRUD + ProductPrice + import confermato.
- Inventario/stock adjustment resta fuori MVP o viene motivato esplicitamente.
- Lo schema pending salva intenzione/stato/chiave logica, non payload massivi.
- Le regole UI non duplicano banner/card di TASK-091/092.
- Accessibilità/localizzazione sono considerate senza introdurre stringhe in planning.
- State machine, cleanup, migration, delete/tombstone e coalescing sono abbastanza definiti per scrivere codice senza fermarsi su micro-scelte.
- TASK-094+ restano non aperti.

---

## 9.5 Snapshot API candidata verso Release / TASK-094

Contratto candidato, solo planning:

- `totalPendingCount`
- `pendingByEntityKind`
- `pendingByStatus`
- `blockedCount`
- `staleBaselineCount`
- `supersededCount`
- `isCapped`
- `capDescription` privacy-safe
- `requiresCloudCheckBeforePush`
- `lastLocalChangeAt`
- `primaryUserMessageKey` / copy key futura, non stringa hardcoded in planning
- `recommendedNextAction`: none / reviewRemoteFirst / reviewLocalPending / retryCheck

Regola: lo snapshot deve essere **read-only**, **senza rete**, **fakeable nei test**, e consumabile dalla UI senza esporre liste raw di barcode/nomi prodotto.

---

## 9.6 Riconciliazione pending dopo pull/apply remoto

Regole candidate:

| Evento remoto/apply locale | Pending locale candidato | Nota |
|----------------------------|--------------------------|------|
| Remote update stessa logical key, pending locale update | `staleBaseline` | Richiede nuovo controllo prima di push |
| Remote delete/tombstone stessa logical key, pending locale update | `blocked` | Evita ricreazione o overwrite ambigua |
| Remote state uguale al payload derivabile locale | `superseded` | L’intenzione locale è già soddisfatta |
| Remote update indipendente | resta `pending` | Nessun conflitto logico |
| Owner/session cambiata | `blocked` o pending non consumabile | Fail-closed, nessun push |

Nessuna regola di riconciliazione deve eseguire push, drain o cleanup distruttivo in TASK-093.

---

## 9.7 Performance budget e query SwiftData candidate

- Snapshot Release: calcolo on-demand da service/ViewModel, mai dal body della View.
- Query primaria: pending con `status in [pending, blocked, staleBaseline]`, opzionalmente filtrati per `entityKind`.
- Dedupe/coalescing: lookup per `logicalKey + entityKind + operation compatibile`.
- Ordinamento stabile: `updatedAt DESC`, con cap e fallback user-facing se superato.
- Test performance futuri: dataset sintetico con molti pending ma pochi rilevanti; verificare che non venga caricato tutto il catalogo per mostrare solo il summary.

---

## 9.8 Gate finale consigliato prima di chiedere Execution

Quando Claude chiude la review planning, il file deve essere considerato pronto solo se:

- Le sezioni **§9.1…§9.8** sono presenti, **§9.1…§9.7** in ordine logico previsto e **non duplicate**.
- Tutti i riferimenti CA usano lo stesso range `CA-T093-01…34`.
- Il plan non contiene promesse di push, drain, background o Supabase write in TASK-093.
- Il MASTER-PLAN resta coerente: TASK-093 ACTIVE / PLANNING, TASK-094+ non aperti.
- Il prossimo messaggio operativo deve chiedere esplicitamente un override utente per passare a EXECUTION.

---

## 10. Acceptance criteria (futura EXECUTION / review — contratto TASK-093)

*Prefisso **CA-T093-01 … CA-T093-34**; verificabili dopo implementazione autorizzata.*

- **CA-T093-01:** Esiste un **design documentato** (nel file task + codice) che distingue **modifica locale persistente**, **pendenza verso cloud**, **inviata**, **obsoleta** (superseded), **non sincronizzabile** (blocked), senza ambiguità con solo `SyncEventOutboxStatus`.
- **CA-T093-02:** Il modello di accumulo è **bounded** (cap espliciti per numero di record e/o `changed_count` aggregato coerente con contratto `record_sync_event`).
- **CA-T093-03:** **Deduplica / coalescing** definiti per almeno **Product** e **Supplier/Category** (chiave e politica di merge last-write o scoped field-set documentata).
- **CA-T093-04:** **ProductPrice:** politica di accumulo non crea **explosion** di righe duplicate locali né payload illimitati; rispetta vincoli di identità logica noti.
- **CA-T093-05:** **Privacy:** log, debug e snapshot UI **non** espandono liste di barcode/nomi in chiaro oltre i campioni consentiti dalla policy Release esistente.
- **CA-T093-06:** **Stale baseline / session:** transizioni fail-closed documentate (es. discard pendings, mark blocked, richiesta re-check) quando owner/session/baseline non è più valida.
- **CA-T093-07:** **TASK-094 hook:** è definito un **API interno** (tipi/protocolli) per “ottenere snapshot dirty bounded” **senza** attivare rete; push reale **non** richiesto in TASK-093.
- **CA-T093-08:** **Test:** almeno una suite **fakeable** copre enqueue → dedupe → invalidazione stale (Swift **in execution**, non in questo turno).
- **CA-T093-09:** **No regressioni** su flussi Release esistenti: apply/push/drain **restano** manuali/confermati come oggi finché TASK-094 non li estende (verifica regression da definire in review).
- **CA-T093-10:** Documentazione **handoff TASK-094** completa in sezione §13 aggiornata post-execution.
- **CA-T093-11:** **MVP scope esplicito:** la futura execution deve dichiarare quali superfici entrano nella v1 del dirty set e quali restano out-of-scope; default consigliato: catalogo CRUD + ProductPrice + import confermato, non ogni cella/HistoryEntry grezzo.
- **CA-T093-12:** **UX/UI Release:** è definito un presenter/state model che espone conteggi aggregati “modifiche locali in attesa” senza duplicare CTA, banner o stati già coperti da TASK-091/092.
- **CA-T093-13:** **Efficienza:** snapshot dirty bounded ottenibile senza full reload ripetuti, N+1 query o lavoro pesante nel body SwiftUI; limiti e fallback documentati.
- **CA-T093-14:** **Decisioni autonome:** se due alternative sono equivalenti, la futura execution deve scegliere quella più semplice, iOS-native e coerente con la UI esistente, registrando la decisione in tabella `Decisioni` senza fermarsi per micro-scelte estetiche.
- **CA-T093-15:** **No over-logging:** eventuali debug/test usano conteggi, hash o fixture controllate; niente log massivi di barcode, nomi prodotto, supplier o payload Excel.
- **CA-T093-16:** **State machine esplicita:** stati e transizioni pending/superseded/blocked/stale/sent documentati e coperti da test fakeable.
- **CA-T093-17:** **Atomicità locale:** ogni punto che persiste una modifica MVP deve registrare o aggiornare il pending nello stesso flusso logico; eventuali gap devono avere recovery documentata.
- **CA-T093-18:** **Cleanup bounded:** record inviati/superseded hanno retention/cap chiari, senza crescita illimitata del database locale.
- **CA-T093-19:** **Schema minimalista:** il pending store non duplica payload completi di prodotto, HistoryEntry o griglie Excel quando può derivarli dai modelli locali correnti.
- **CA-T093-20:** **SwiftData migration impact:** se viene aggiunto un nuovo modello SwiftData, la futura execution deve verificare container/schema, migration leggera e compatibilità con dati esistenti prima di dichiarare READY FOR REVIEW.
- **CA-T093-21:** **Commit boundary:** pending locale viene creato/aggiornato solo dopo azioni confermate e persistite; nessun pending per digitazione temporanea o sheet non salvati.
- **CA-T093-22:** **Coalescing deterministico:** create/update/delete/ProductPrice/import hanno regole documentate e testate per evitare duplicati e payload ridondanti.
- **CA-T093-23:** **Reentrancy/idempotenza locale:** edit rapidi, import ripetuti o multi-scene non generano pending duplicati non necessari per la stessa logical key.
- **CA-T093-24:** **Review planning checklist:** prima di EXECUTION sono verificati MVP, no auto-push, no payload massivi, UI coerente, migration/cleanup/coalescing definiti e TASK-094+ chiusi.
- **CA-T093-25:** **Accessibilità/localizzazione:** UX futura del pending è compatibile con Dynamic Type/VoiceOver e usa copy breve/localizzabile, senza introdurre stringhe in planning.
- **CA-T093-26:** **Delete/tombstone fail-closed:** delete locale con identità remota nota ha semantica esplicita; casi senza contesto sufficiente diventano no-op/superseded/blocked, mai push distruttivo ambiguo.
- **CA-T093-27:** **Inventory fuori MVP:** aggiustamenti stock/inventario sono esclusi dal MVP o motivati con decisione esplicita e cap dedicati.
- **CA-T093-28:** **Schema version/origin:** pending record include o pianifica `schemaVersion` e `origin` per migration, debug privacy-safe e futura evoluzione TASK-094+.
- **CA-T093-29:** **Snapshot API read-only:** esiste o è definito un provider snapshot locale bounded, senza rete, fakeable e consumabile sia da Release UI sia da TASK-094.
- **CA-T093-30:** **No raw identifiers in UI snapshot:** snapshot e presenter espongono conteggi/stati/copy key, non liste raw di barcode, nomi prodotto o supplier.
- **CA-T093-31:** **Riconciliazione post-pull:** pending locali diventano stale/blocked/superseded secondo regole documentate quando un pull/apply remoto modifica la stessa logical key.
- **CA-T093-32:** **Query/index planning:** campi candidati per filtro/sort (`status`, `entityKind`, `logicalKey`, `updatedAt`) sono definiti prima della patch SwiftData.
- **CA-T093-33:** **Performance budget:** snapshot UI non richiede full scan di catalogo/history e ha cap/fallback user-facing quando i pending superano la soglia.
- **CA-T093-34:** **TASK-094 consumer contract:** il handoff finale descrive chiaramente quali campi snapshot TASK-094 può consumare e quali invarianti deve ricontrollare prima di qualunque push.

---

## 11. Rischi (R93-xx)

- **R93-01:** Duplicazione concettuale tra **dirty catalog** e **SyncEventOutboxEntry** → inconsistenze doppia fonte di verità.
- **R93-02:** Scope troppo ampio su **HistoryEntry** / inventario → costo storage e privacy.
- **R93-03:** ProductPrice **effective_at** / timezone → accumulo errato o conflitti silenziosi.
- **R93-04:** Performance: osservare SwiftData su dataset grandi senza indici/query pesanti.
- **R93-05:** UX: sovrapposizione con “pending” già mostrato da snapshot TASK-069/091 → confusione utente.
- **R93-06:** Complessità **prematura** prima di TASK-094 → mitigare con MVP dirty **solo catalog** prima di estendere a tutte le superfici.
- **R93-07:** UI Release troppo rumorosa dopo TASK-091/092 → mitigare con un solo punto informativo compatto e priorità chiara tra remote changes e local pending.
- **R93-08:** Dirty store troppo verboso su import Excel/History → mitigare salvando intenzioni/logical keys, non copie massicce della griglia.
- **R93-09:** Query costose su SwiftData con molti pending → mitigare con indici/stati filtrabili, cap e snapshot costruiti fuori dal body SwiftUI.
- **R93-10:** Pending registrato ma modifica locale non salvata, o viceversa → mitigare con transaction boundary/flow unico e test recovery.
- **R93-11:** Nuovo modello SwiftData rompe container/migration leggera → mitigare con preflight schema, dati esistenti e test in-memory + persistent store.
- **R93-12:** Delete/tombstone locale non distinto da update → mitigare con `operation` esplicita e fail-closed se il modello dominio non conserva abbastanza contesto.
- **R93-13:** Dirty storm da digitazione/form temporanei → mitigare creando pending solo su commit/salvataggio confermato.
- **R93-14:** Duplicati da edit rapidi o multi-scene → mitigare con store serializzato/idempotente e unique logical key dove possibile.
- **R93-15:** Coalescing sbagliato su create/delete → mitigare con regole esplicite e test su sequenze di operazioni.
- **R93-16:** UI non accessibile con Dynamic Type/VoiceOver → mitigare con summary breve, sheet di dettaglio e label conteggi.
- **R93-17:** Inventario mischiato al catalog pending → mitigare lasciandolo fuori MVP salvo task dedicato.
- **R93-18:** Evoluzione schema pending difficile → mitigare con `schemaVersion` e `origin` fin dalla progettazione.
- **R93-19:** Snapshot UI accoppiato troppo al futuro push TASK-094 → mitigare con provider read-only e consumer contract separato.
- **R93-20:** Pull remoto rende pending locale stale ma la UI lo mostra ancora inviabile → mitigare con riconciliazione e `requiresCloudCheckBeforePush`.
- **R93-21:** Full scan su catalogo/history per costruire summary → mitigare con query filtrate, indici candidati e cap.
- **R93-22:** Presenter espone identificativi raw in UI/log → mitigare con conteggi aggregati e copy key localizzabili.

---

## 12. Go / No-Go per futura EXECUTION

**Go** solo se sono soddisfatti **tutti**:

1. Planning review **APPROVED** (Claude) con decisione su **modello dati**; default raccomandato: nuovo modello SwiftData leggero `LocalPendingChange`/equivalente, salvo evidenza contraria dopo lettura codice. Deve essere fissato anche il perimetro **MVP**: catalogo CRUD + ProductPrice + import confermato come candidati primari; History/Excel full payload solo se strettamente necessario e bounded.
2. **Decisione migration presa prima di EXECUTION** se viene introdotto un nuovo modello SwiftData: strategia container/schema, migration leggera, compatibilità con store esistenti (allineato a **CA-T093-20**).
3. **Decisione cleanup/retention presa prima di scrivere codice:** cap record, policy per sent/superseded, fallback user-facing al raggiungimento del limite (allineato a **CA-T093-18** e **D93-09**).
4. Handoff esplicito utente **PLANNING → EXECUTION** e responsabile **Codex / Executor** nominato.
5. **TASK-094+** restano **chiusi** fino a completamento TASK-093.
6. Criteri **CA-T093-01 … CA-T093-34** confermati o raffinati senza contraddire **TASK-071**/`changed_count`.
7. UX decision presa: il pending locale futuro deve apparire nella Release card come **summary aggregato**, non come nuova schermata principale né come secondo banner permanente.
8. Performance decision presa: qualunque snapshot per UI/push plan deve essere **pull-based/call-based**, non osservato continuamente con polling o lavoro automatico.
9. Commit-boundary decision presa: pending solo su salvataggio/conferma, non su input temporaneo.
10. Coalescing decision presa: sequenze create/update/delete/ProductPrice/import hanno regole candidate prima della patch.
11. Reentrancy decision presa: lo store pending o il servizio accumulator deve essere idempotente/serializzato quanto basta per edit rapidi e multi-scene.
12. Accessibilità/localizzazione decision presa: UI pending futura deve avere copy breve, Dynamic Type/VoiceOver safe e nessuna nuova stringa in planning.
13. Delete/tombstone decision presa: nessun push distruttivo ambiguo se manca remoteID o baseline sufficiente.
14. Inventario decision presa: stock adjustment fuori MVP salvo decisione esplicita separata.
15. Snapshot API decision presa: provider read-only/fakeable, campi minimi e consumer contract verso TASK-094 definiti prima della patch.
16. Riconciliazione decision presa: regole post-pull per stale/blocked/superseded definite prima di scrivere codice.
17. Query/performance decision presa: campi filtrabili/sort e cap snapshot definiti prima di aggiungere modello SwiftData.

**No-Go** se: modello ancora indefinito; duplicazione outbox/dirty non risolta; o perimetro che include **push automatico** o **background obbligatorio**; **o** mancano decisioni esplicite su migration SwiftData (se nuovo modello) o su cleanup/retention prima dell’inizio dell’implementazione.

---

## 13. Handoff finale (questo turno — planning refinements)

- **READY FOR PLANNING REVIEW** — contenuto TASK-093 da revisionare prima di qualsiasi Swift; include MVP, schema minimo §9.1, UX/accessibilità §9.2, coalescing §9.3, checklist §9.4, snapshot API §9.5/S93-L, riconciliazione §9.6/S93-M, performance §9.7/S93-N, **gate finale review planning §9.8**, state machine §S93-I, commit boundary §S93-J, delete/inventario §S93-K, CA **01…34**, Go/No-Go aggiornato.
- **NON READY FOR EXECUTION** — nessuna implementazione autorizzata da questo file finché review + override utente.
- **TASK-093 NON DONE** — stato **ACTIVE / PLANNING** soltanto.
- **TASK-094, TASK-095, TASK-096:** **TODO / Planning — non aperti** (nessun file task creato per essi in questo turno).

### Handoff → Planning review (Claude)

- **Prossima fase:** PLANNING (review interna / utente) → poi eventualmente **EXECUTION** dopo override.
- **Prossimo agente:** **Claude / Planner** (review) → **Codex / Executor** solo dopo handoff formale.
- **Azione consigliata:** Approvare modello pending/outbox; validare §9.1…§9.7 e **§9.8**; fissare migration + cleanup/retention + commit boundary + coalescing + delete/tombstone + inventario fuori MVP + snapshot API + riconciliazione post-pull **prima** del primo commit Swift; aggiornare CA solo se necessario **prima** di EXECUTION.

---

## Non incluso (anti-scope TASK-093)

- Push intelligente, batch remoto, drain automatico, **qualunque** write Supabase da nuovo codice TASK-093.
- Timer/BGTask/Realtime/polling/worker **reali**.
- Modifiche **Android/Kotlin**, **SQL**, **RLS**, **migration**, **Localizable.strings**, **project.pbxproj** nel perimetro TASK-093 salvo futuro task/override.
- Chiusura **TASK-094+** o claim **production-ready** globale.

---

## Planning (Claude)

### Analisi

La codebase iOS ha già **pezzi** di pipeline sync (**pull/push guidati**, **outbox `sync_events`** su outcome terminali, **state machine** robusta) ma manca una **vista unificata** “quali modifiche locali sono **intenzionate** per il cloud e in quale stato” che preceda il push aggregato di TASK-094. TASK-093 deve colmare quel gap **a livello di modello e policy**, senza anticipare la rete.

### Approccio proposto

1. Completare **S93-A** in EXECUTION con grep/lettura file §8.
2. Usare come default un modello SwiftData separato e leggero `LocalPendingChange`/equivalente, con campi minimi e payload derivabile; scartarlo solo se la lettura codice dimostra che un'estensione dei modelli esistenti è chiaramente più sicura.
3. MVP consigliato: **Database CRUD catalogo + ProductPrice + import confermato**. Rimandare History/Excel raw payload, inventario complesso e tracking cella-per-cella finché non servono davvero.
4. Esporre **snapshot bounded** per ViewModel Release: conteggi aggregati, severità, stato recoverable/blocked/stale; nessuna rete e nessun push.
5. UX futura: integrare nella card Release esistente con disclosure progressiva; una sola CTA primaria quando TASK-094 sarà disponibile; niente duplicazione del banner foreground TASK-092.
6. Efficienza: niente query pesanti nel body SwiftUI; niente full reload ripetuti; batch/mappe costruite fuori dal render; cap e fallback documentati.
7. Definire state machine, cleanup, commit boundary e coalescing prima della patch: pending/superseded/blocked/stale/sent, retention/cap, recovery da inconsistenza locale, no pending su input temporaneo.
8. Handoff **TASK-094**: snapshot API + invarianti pre-write (auth/owner/baseline), più out-of-scope espliciti.
9. Definire provider snapshot read-only e regole post-pull prima di qualsiasi UI: la card Release legge solo summary aggregati e TASK-094 dovrà rifare auth/owner/baseline prima del push.

### Raffinamento UX/UI ed efficienza (integrazione planning)

- **Scelta UX default:** pending locale dentro la card Release, non nuova tab/schermata. Mostrare prima un testo breve e conteggi; dettagli solo in sheet/disclosure.
- **Priorità stati:** se ci sono remote changes da applicare e local pending da inviare, la UI deve guidare prima l’utente a rendere il dispositivo aggiornato, poi preparare l’invio locale in TASK-094.
- **Copy:** evitare jargon come `dirty`, `outbox`, `baseline`; usare messaggi tipo “Modifiche locali in attesa”, “Da ricontrollare”, “Non inviabili ora”.
- **Performance:** lo snapshot UI deve essere calcolato on-demand da ViewModel/Service, non dal body della View; ordinamenti e dedupe su background actor/task dove opportuno.
- **Scelta autonoma:** in execution, se due layout sono equivalenti, scegliere quello più coerente con SwiftUI/iOS e con le card Release già esistenti, senza chiedere micro-conferme.
- **Microcopy suggerita:** `Modifiche locali in attesa`, `Da ricontrollare`, `Non inviabili ora`, `Aggiorna prima questo dispositivo`; evitare parole tecniche o inglesismi nella UI finale.
- **Layout suggerito:** riga summary nella card Release + eventuale sheet di dettaglio; non aggiungere una seconda card fissa se la card Release può ospitare lo stato senza diventare affollata.
- **Input temporaneo:** non mostrare pending mentre l’utente sta ancora modificando un form; lo stato compare solo dopo salvataggio/conferma, così la UX resta stabile e non ansiogena.

### File da modificare (futura EXECUTION — ipotesi)

Da determinare dopo S93-A; attesi sotto `iOSMerchandiseControl/` per modelli + servizio accumulator + hook puntuali Database/ProductPrice; test sotto `iOSMerchandiseControlTests/`.

### Rischi identificati

Vedi §11 (R93-xx).

### Handoff post-planning (stato corrente)

- **Prossima fase:** PLANNING (review) — **non** EXECUTION.
- **Prossimo agente:** **Claude / Planner** (review planning).
- **Azione consigliata:** Validare §9 (micro-slice), §9.1…§9.8, §10 (**CA-T093-01…34**), §11, §12.

---

## Execution (Codex)

### Avvio EXECUTION — 2026-05-09 22:13 -0400

- **Override esplicito:** l'utente ha autorizzato l'esecuzione completa di TASK-093 con modifiche Swift/SwiftUI/SwiftData, XCTest, build Debug/Release, Simulator se necessario e verifiche Supabase solo sicure/read-only salvo test controllati davvero necessari.
- **Obiettivo compreso:** implementare un accumulo locale iOS-native delle modifiche locali: pending/dirty set locale bounded, deduplicato, retry-safe, privacy-safe e consumabile in futuro da TASK-094, senza push intelligente, senza drain/apply automatici e senza background sync.
- **Perimetro MVP confermato:** catalogo CRUD locale, ProductPrice, import confermato. Fuori MVP: celle grezze Excel, payload raw HistoryEntry, stock/inventory adjustment salvo decisione esplicita motivata.
- **Tracking iniziale verificato:** MASTER-PLAN indica TASK-093 come unico task attivo; file task reale corrisponde al path dichiarato; TASK-092 resta ultimo completato **DONE / Chiusura — REVIEW PASS**; nessun file TASK-094/TASK-095/TASK-096 presente.
- **Stato iniziale impostato:** **TASK-093 ACTIVE / EXECUTION**, responsabile **Codex / Executor**, **NON DONE**.
- **Piano minimo:** leggere codice iOS reale e test esistenti; mappare superfici mutanti; aggiungere modello/store pending leggero se confermato dalla lettura; implementare coalescing/state machine/snapshot/reconciliation; cablare solo punti commit confermati; aggiornare Release summary aggregato solo se coerente; aggiungere XCTest fakeable; build/test/check anti-scope; handoff finale a **REVIEW**.
- **Divieti confermati:** nessun push intelligente, nessun auto sync/background, nessun write Supabase live come feature, nessun Android/Kotlin, nessun SQL/RLS/migration/backend, nessun TASK-094+.

### Completamento EXECUTION — 2026-05-09 22:59 -0400

- **Obiettivo eseguito:** introdotto accumulo locale iOS-native delle modifiche locali con modello SwiftData leggero `LocalPendingChange`, accumulator service, coalescing deterministico, state machine minima, cleanup bounded, snapshot provider read-only/fakeable e riconciliazione post-pull/baseline refresh.
- **Superfici MVP coperte:** catalogo CRUD locale (`Product`, `Supplier`, `ProductCategory`), `ProductPrice`, import confermato CSV/full database/ProductImport. Pending registrati solo su azioni confermate/salvate; nessun pending su digitazione temporanea nei form/sheet.
- **Superfici fuori MVP mantenute fuori:** celle grezze Excel, payload raw `HistoryEntry`, stock/inventory adjustment.
- **Store pending:** salva intenzione, `entityKind`, `operation`, `status`, `origin`, `logicalKey` privacy-safe, changed fields compatti, fingerprint hash opzionali, timestamp e riferimenti minimi; non salva payload completi prodotto/supplier/HistoryEntry/griglie Excel.
- **Coalescing implementato:** create→update resta create con fields compatti; update→update resta update unico; update→delete diventa delete/tombstone; create locale mai inviato→delete diventa superseded/no-op; ProductPrice coalescing per `(product,type,effectiveAt)`; import confermato registra logical keys con cap e marker aggregato.
- **State machine implementata:** `pending`, `superseded`, `blocked`, `staleBaseline`, `sent`, `acknowledged`; cleanup retention per terminali; owner/session/snapshot fail-closed.
- **Snapshot Release/TASK-094:** `LocalPendingChangeSnapshotProvider` e adapter Release restituiscono conteggi aggregati catalogo/ProductPrice/blocked/stale/sent/superseded/capped, senza rete, push, drain o raw identifiers. La Release factory usa il pending locale come fonte primaria e conserva fallback read-only esistente.
- **Riconciliazione post-pull:** stessa logical key remota uguale all'intenzione → `superseded`; remota tombstone → `blocked`; fingerprint remota diversa dalla baseline → `staleBaseline`; chiavi indipendenti restano `pending`.
- **Query/performance:** lookup coalescing per `entityKind + logicalKey`, snapshot on-demand da service/provider, sort stabile per `updatedAt`, cap active changes/import e nessun calcolo nel body SwiftUI.
- **Privacy/log:** logical key e fingerprint hash; snapshot e test usano conteggi; nessun log massivo di barcode, nomi prodotto o supplier. Nuovo log runtime introdotto solo generico: `Errore durante il salvataggio locale.`
- **Note schema SwiftData:** gli UUID del pending sono serializzati come stringhe canoniche dove non serve relazione SwiftData diretta, per migration leggera e stabilita' del modello. `LocalPendingChange` e' stato aggiunto al model container app/previews.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-093-local-change-accumulation-ios.md`
- `docs/TASKS/TASK-091-supabase-smart-semi-automatic-sync-ios.md`
- `docs/TASKS/TASK-092-lightweight-auto-pull-foreground-ios.md`
- `docs/TASKS/TASK-088-product-price-manual-push-ios.md`
- `docs/TASKS/TASK-080-product-price-sync-ios.md`
- `docs/TASKS/TASK-081-sync-events-outbox-release-ios.md`
- `docs/TASKS/TASK-082-supabase-product-tombstone-parity-ios.md`
- `docs/TASKS/TASK-086-supabase-catalog-delete-sync-ios.md`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/EditProductView.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/InventoryHomeView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxState.swift`
- `iOSMerchandiseControl/SyncEventOutboxLocalStore.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- test esistenti Release/manual sync/ProductPrice/outbox.

### Modifiche fatte

- Aggiunto `iOSMerchandiseControl/LocalPendingChange.swift` con modello SwiftData, accumulator, snapshot provider, adapter Release, logical keys hash e riconciliazione.
- Aggiornato model container app/previews per includere `LocalPendingChange`.
- Cablato pending su salvataggio confermato catalogo, delete catalogo, import CSV/full database/ProductImport e ProductPrice.
- Aggiornato `SupabaseManualSyncLocalPendingSnapshotProvider` per contare ProductPrice e usare il nuovo adapter locale, mantenendo il fallback preesistente.
- Aggiornati/aggiunti test XCTest: `LocalPendingChangeAccumulatorTests` e `SupabaseManualSyncLocalPendingSnapshotProviderTests`.

### Check eseguiti

- ✅ ESEGUITO — `git status --short`: working tree con modifiche TASK-093 attese e task file TASK-093 untracked preesistente/nuovo; nessuna modifica Android/Kotlin/SQL.
- ✅ ESEGUITO — `git diff --check`: PASS, nessun whitespace error.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: PASS, scheme `iOSMerchandiseControl` disponibile.
- ✅ ESEGUITO — Build Debug iPhone 17 Pro iOS 26.4.1 Simulator: PASS (`/tmp/task093-debug-build-final.log`), unico warning AppIntents metadata preesistente/toolchain.
- ✅ ESEGUITO — Build Release iPhone 17 Pro iOS 26.4.1 Simulator: PASS (`/tmp/task093-release-build-final.log`), unico warning AppIntents metadata preesistente/toolchain.
- ✅ ESEGUITO — XCTest mirati TASK-093/provider: PASS 24/0.
- ✅ ESEGUITO — XCTest regressione Release/manual sync/ProductPrice/outbox: PASS 295/0.
- ✅ ESEGUITO — Full XCTest: PASS 604/0 (`Test-iOSMerchandiseControl-2026.05.09_22-58-05--0400.xcresult`).
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile in build Debug/Release: PASS. Warning residuo build: AppIntents metadata, preesistente/toolchain. Warning residui full test: `SyncEventOutboxDrainDebugViewModelTests.swift` non-Sendable closure conversion, preesistenti e fuori scope TASK-093.
- ✅ ESEGUITO — Criteri di accettazione verificati staticamente/test: CA-T093-01…34 coperti da codice/test/handoff, con TASK-094 consumer contract preparatorio e nessun push.
- ✅ ESEGUITO — Anti-scope codice: nessun Timer/BGTask/Realtime/polling/worker nuovo; nessun push intelligente/auto push/drain/apply remoto; nessun TASK-094/095/096 in codice; nessun segreto/JWT/refresh token/connection string; nessun Android/Kotlin; nessun SQL/RLS/migration/backend.
- ⚠️ NON ESEGUIBILE — `plutil` Localizable: non applicabile, nessun `Localizable.strings` modificato.
- ⚠️ NON ESEGUIBILE — Supabase write/test integrazione live: non necessario e fuori feature TASK-093; implementazione e test sono fake/in-memory/local.
- ⚠️ NON ESEGUIBILE — Simulator UI manuale: non richiesto esplicitamente per questo task e UI visibile non introduce nuova schermata/CTA; verifiche standard static/build/test completate.

### Rischi rimasti

- Migrazione da store locali creati durante run sperimentali non rilasciati con schema intermedio `LocalPendingChange` UUID puo' fallire sul simulatore usato per debug; su simulatore fresco e schema finale la migration leggera/build/test passano. Non e' un rischio utente da versione rilasciata, ma e' tracciato per reviewer.
- TASK-094 deve rifare comunque auth/owner/baseline/pre-write recheck prima di qualsiasi push: TASK-093 espone solo accumulo/snapshot locale.
- Follow-up candidate fuori scope: eventuale estensione futura a stock/inventory adjustment richiede task dedicato e UX separata.

### Handoff post-execution → Review (Claude)

- **Stato finale:** **TASK-093 ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **NON DONE**.
- **Handoff:** **READY FOR REVIEW**.
- **TASK-094, TASK-095, TASK-096:** restano **TODO / Planning — non aperti**; nessun file task creato.
- **Ultimo completato invariato:** **TASK-092 DONE / Chiusura — REVIEW PASS**.

---

## Review (Claude)

### Esito review

- **Decisione finale:** **REVIEW PASS**
- **Stato finale:** **TASK-093 DONE / Chiusura — REVIEW PASS** *(override esplicito utente per chiusura DONE da Codex reviewer/fixer)*.
- **TASK-094, TASK-095, TASK-096:** **TODO / Planning — non aperti**.
- **Ultimo completato precedente:** **TASK-092 DONE / Chiusura — REVIEW PASS**.
- **Supabase live:** nessun write live usato; verifiche locali/fake/in-memory.
- **Claim production-ready globale:** non espresso.

### Ambito analizzato

Review tecnica completa su tracking, diff corrente, `LocalPendingChange`, snapshot Release, model container/previews, commit hook CRUD/import/ProductPrice e XCTest. Verificati: MVP catalogo CRUD + ProductPrice + import confermato, no pending su digitazione temporanea, no payload raw HistoryEntry/Excel, stock/inventory fuori MVP, state machine, coalescing, owner/session fail-closed, privacy/log, query bounded e anti-scope.

### Problemi trovati e fix applicati

1. **Owner scoping troppo permissivo:** i pending con `ownerUserID == nil` venivano considerati compatibili con qualunque owner firmato. Fix: snapshot e accumulator ora sono fail-closed per owner firmato; ownerless resta non consumabile da Release/TASK-094.
2. **Snapshot locale letto due volte nella Release factory:** catalogo e ProductPrice usavano lo stesso adapter con due fetch separati. Fix: aggiunto counter combinato read-only per caricare lo snapshot locale una sola volta e chiamare il fallback catalogo solo se non ci sono pending catalog locali.
3. **Commit boundary delete/save migliorabile:** delete catalogo usava `try?` e poteva salvare la cancellazione senza pending se la registrazione falliva. Fix: record pending + delete nello stesso `do`, rollback su errore e log generico privacy-safe. Aggiunto rollback anche su save prodotto/import ViewModel.
4. **GeneratedView non propagava owner:** edit/import da `GeneratedView` creavano pending ownerless. Fix: aggiunto `SupabaseAuthViewModel` environment e passaggio owner a `EditProductView` / `ProductImportViewModel`.
5. **Cap marker import/manuale poco esplicito:** superamento cap ora registra marker bounded `blocked`/capped anche fuori import, senza salvare identificativi raw.
6. **ProductPrice effectiveAt:** chiave/fingerprint ora usano microsecondi invece di secondi interi, riducendo collisioni sul coalescing `(product,type,effectiveAt)`.

### Verifiche review

| Check | Esito | Evidenza |
|---|---:|---|
| `git status --short` | ✅ PASS | Working tree coerente con TASK-093; nessun Android/Kotlin/SQL/migration. |
| `git diff --check` | ✅ PASS | Nessun whitespace error. |
| `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | ✅ PASS | Scheme `iOSMerchandiseControl` presente. |
| Build Debug simulator iPhone 17 Pro | ✅ PASS | `xcodebuild ... -configuration Debug build` PASS; log quiet senza warning/error. |
| Build Release simulator iPhone 17 Pro | ✅ PASS | `xcodebuild ... -configuration Release build` PASS; log quiet senza warning/error. |
| XCTest mirati TASK-093/provider | ✅ PASS | `LocalPendingChangeAccumulatorTests` + `SupabaseManualSyncLocalPendingSnapshotProviderTests`: **25 test / 0 failure**. |
| Regressione Release/manual sync/ProductPrice/outbox | ✅ PASS | Suite mirate: **356 test / 0 failure**. |
| Full XCTest | ✅ PASS | Full suite: **605 test / 0 failure**, xcresult `Test-iOSMerchandiseControl-2026.05.09_23-14-38--0400.xcresult`. |
| Anti-scope diff codice | ✅ PASS | Nessun nuovo Timer/BGTask/Realtime/polling/worker, push automatico, drain automatico, TASK-094+, segreti/token/JWT/service_role/connection string. |
| Kotlin/Android diff | ✅ PASS | Nessun file Kotlin/Android modificato. |
| SQL/RLS/migration/backend | ✅ PASS | Nessun file SQL/migration/backend modificato. |
| Privacy/log | ✅ PASS | Solo log generici su save/delete; nessun barcode/nome prodotto/supplier/token in log nuovi. |
| `plutil` Localizable | ⚠️ NON ESEGUIBILE | Non applicabile: nessun `Localizable.strings` modificato. |
| Supabase write live | ⚠️ NON ESEGUIBILE | Non necessario e fuori feature TASK-093; task locale/read-only. |

### Note warning

- Durante i test mirati/regressione sono ricomparsi 4 warning Swift preesistenti in `SyncEventOutboxDrainDebugViewModelTests.swift` su conversione di funzioni non-Sendable. Il file non e' stato modificato da TASK-093 e tutte le suite PASS.
- Nessun warning nuovo attribuibile ai file TASK-093 nei build Debug/Release finali.

### Decisione

TASK-093 soddisfa i criteri CA-T093-01…34: modello pending locale minimalista e bounded, coalescing deterministico, state machine esplicita, cleanup/retention, snapshot read-only/fakeable senza rete, owner/session fail-closed, riconciliazione post-pull, ProductPrice per chiave logica, import confermato con cap, Release summary aggregato, privacy-safe, nessun push/sync automatico e nessuna apertura TASK-094+.

---

## Fix (Codex)

- **2026-05-09 23:15 -0400 — Fix review applicati:** owner scoping fail-closed; snapshot Release locale combinato; delete/save rollback e atomicità migliore; owner propagato da `GeneratedView`; cap marker blocked/capped; ProductPrice effectiveAt microsecond key; test aggiornati per ownerless/cap/snapshot combinato.

---

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|----------------------|-------------|--------|
| D93-00 | MVP consigliato: catalogo CRUD + ProductPrice + import confermato | Coprire subito History/Excel raw payload e ogni cella modificata | Riduce rischio, storage e rumore UI; prepara TASK-094 senza overengineering | proposta planning |
| D93-01 | TASK-093 **non** implementa push intelligente | Unificare 093+094 in un solo task | Sequenza utente: accumulo prima, push dopo | attiva |
| D93-02 | Android solo riferimento funzionale | Porting 1:1 WorkManager/outbox | Architettura Apple-native | attiva |
| D93-03 | Supabase solo contratto read-only in questo turno | Schema/migration in TASK-093 | Divieto esplicito user | attiva |
| D93-04 | Preferire nuovo modello SwiftData leggero per pending locale | Molti flag sparsi sui modelli dominio | Separazione chiara tra dato locale e intenzione sync; più facile dedupe/retry | proposta planning |
| D93-05 | Pending locale futuro visibile nella card Release come summary aggregato | Nuova schermata principale o secondo banner permanente | UX più coerente con TASK-091/092 e meno rumorosa | proposta planning |
| D93-06 | Snapshot pending on-demand/call-based | Osservazione continua, polling o calcoli nel body SwiftUI | Migliore performance e minore rischio di regressioni su dataset grandi | proposta planning |
| D93-07 | Pending store salva intenzione/stato/chiave logica, non payload completo | Duplicare `Product`/griglia Excel in ogni record pending | Meno storage, coalescing migliore, allineamento §9.1 | attiva (planning) |
| D93-08 | State machine minima documentata prima della prima patch Swift | Stati ad-hoc sparsi nel codice | Tracciabilità, test, recoverability | attiva (planning) |
| D93-09 | Cleanup/retention obbligatori per sent/superseded | Crescita illimitata pending storici | CA-T093-18, bounded DB locale | attiva (planning) |
| D93-10 | Pending solo su commit/salvataggio confermato | Pending su ogni digitazione o stato temporaneo | Evita dirty storm e UX instabile | proposta planning |
| D93-11 | Coalescing deterministico per create/update/delete/price/import | Accumulare ogni operazione grezza | Riduce duplicati, storage e rischio push ridondante | proposta planning |
| D93-12 | Accumulator idempotente/serializzato quanto basta | Scritture pending concorrenti non coordinate | Protegge da multi-scene, edit rapidi e import ripetuti | proposta planning |
| D93-13 | UI pending progettata per Dynamic Type/VoiceOver | Card densa con liste lunghe | UX iOS più accessibile e coerente con Release | proposta planning |
| D93-14 | Delete/tombstone fail-closed | Push distruttivo ambiguo senza remoteID/baseline | Protezione dati e coerenza Supabase | proposta planning |
| D93-15 | Inventory/stock adjustment fuori MVP | Mescolare inventario e catalog push subito | Riduce rischio semantico e mantiene TASK-093 piccolo | proposta planning |
| D93-16 | Pending record prevede `schemaVersion` e `origin` | Schema implicito non evolvibile | Facilita migration e debug privacy-safe | proposta planning |
| D93-17 | Snapshot provider read-only/fakeable per Release e TASK-094 | UI che legge direttamente store o futuro push plan accoppiato | Migliore testabilità, separazione e anti-scope | proposta planning |
| D93-18 | Riconciliazione post-pull marca pending come stale/blocked/superseded | Lasciare pending inviabili dopo remote apply sulla stessa key | Evita push rischiosi e conflitti silenziosi | proposta planning |
| D93-19 | Query pending filtrate per status/entity/logicalKey/updatedAt | Full scan catalog/history per summary | Performance prevedibile su dataset grandi | proposta planning |
| D93-20 | Presenter espone copy key/conteggi, non identificativi raw | Liste barcode/prodotti nella card Release | Privacy e UI più pulita | proposta planning |

---

## Criteri di accettazione (checkbox operativi)

Da marcare in EXECUTION/REVIEW:

- [x] CA-T093-01 … CA-T093-34 (vedi §10)
- [x] Sezioni §9.1…§9.8 ordinate, non duplicate e coerenti con Planning-only
