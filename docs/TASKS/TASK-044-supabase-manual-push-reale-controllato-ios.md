# TASK-044: Supabase manual push reale controllato iOS — supplier / category / products baseline-gated

## Informazioni generali
- **Task ID**: TASK-044
- **Titolo**: Supabase manual push reale controllato iOS — supplier / category / products baseline-gated
- **File task**: `docs/TASKS/TASK-044-supabase-manual-push-reale-controllato-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / Chiusura *(chi deve agire ORA nella fase corrente)*
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05 *(review tecnica completata con esito APPROVED_FIXED_DIRECTLY; fix diretti applicati; build/test/check PASS; task chiuso DONE su override esplicito utente; nessun push Supabase live reale eseguito)*
- **Ultimo agente che ha operato**: Codex reviewer/fixer

## Dipendenze
- **Dipende da**: **TASK-043** (**DONE / Chiusura** — baseline/fingerprint persistente SwiftData da ultimo full pull/apply riuscito; **prerequisito bloccante** per push reale baseline-gated). **TASK-042**, **TASK-041**, **TASK-040**, **TASK-039**, **TASK-038** (**DONE** — non riaprire).
- **Riferimenti funzionali / Android** *(non codice Kotlin 1:1)*: **TASK-068** (**PARTIAL** — bulk product push client-side con batch bounded e fallback; validazione live bulk/no-op gate ancora pending). **TASK-070** (DONE — retry outbox head-of-line lato app; **iOS TASK-044 non introduce outbox**). **TASK-071** (DONE — mismatch noto su `record_sync_event` / `PayloadValidation` incluso `changed_count > 1000`; **TASK-044 deve evitare completamente `record_sync_event`**).
- **Sblocca**: operatività catalogo remoto incrementale controllata da iOS (solo entità consentite); follow-up futuri esplicitamente fuori scope (ProductPrice push, sync automatico, tombstone outbound, RPC event bus, ecc.).

## Scopo
Implementare il **primo push reale Supabase manuale e controllato** da iOS verso il catalogo remoto, **limitato a** `Supplier`, `ProductCategory` e `Product`, con **auth-gate**, **baseline-gate** (persistenza TASK-043), **preflight/dry-run** senza write, **conferma utente esplicita** prima di ogni scrittura remota, **batch bounded** con fallback conservativo, **idempotenza** per retry sicuro, **aggiornamento identità remota locale** solo dopo successo remoto confermato, e **baseline «valid»** aggiornata **solo** dopo **read-back remoto verificato** (non per semplice copia del piano locale). In caso di push parziale, fallimento o read-back fallito dopo write riuscito: **nessuna** baseline valida falsa; stati UX espliciti (`partial`, `completedBaselineRefreshFailed`, ecc.). Entrypoint solo **UI DEBUG** in `OptionsView`.

## Contesto obbligatorio
- **Repo target**: iOS (`SwiftUI` / `SwiftData` attuale). **Android** = solo riferimento funzionale.
- **Schema Supabase**: considerato condiviso; **non inventare** tabelle/colonne; usare solo DTO/client esistenti allineati allo schema noto.
- **MASTER-PLAN**: dopo chiusura **TASK-043** il progetto era **IDLE**; **TASK-044** diventa task attivo in **PLANNING**. **TASK-032** e **TASK-028** restano **BLOCKED**.
- **Questo turno (refinement planning)**: **solo markdown** nel file task — **nessun** Swift, **nessun** `project.pbxproj` / `Info.plist` / `Package.resolved`, **nessun** SQL/migration/RLS/RPC, **nessun** push reale; fase **ACTIVE / PLANNING** invariata.

## Non incluso (OUT OF SCOPE — vincolante per execution)
- Push o persistenza remota di **`ProductPrice`** / storico prezzi.
- **`record_sync_event`**, **`.rpc`** dedicate a sync events, scritture tabella **`sync_events`**.
- **Outbox**, **dirty queue**, sync **automatico** / **background** / **realtime**.
- **Delete remoto**; tombstone **outbound**; cleanup dati Supabase.
- Modifiche **SQL** / **migration** / **RLS** / policy backend nuove.
- **`service_role`** o segreti elevati lato client.
- Auth nuova o multi-utente avanzato oltre quanto già in **TASK-038**.
- Modifica **Android** / repo non-iOS.
- Validazione live distruttiva su catalogo enorme *(test pianificati su dataset piccolo / mock / incremental)*.

---

## 1. Stato attuale iOS

| Task | Stato | Rilevanza per TASK-044 |
|------|--------|-------------------------|
| **TASK-038** | DONE | Google Auth Supabase foundation; sessione utente; gate obbligatorio pre-push. |
| **TASK-039** | DONE | Apply locale da pull/preview controllato; vincoli partial/conflict/priceHistory. |
| **TASK-040** | DONE | Full pull + bridge identità remota SwiftData (`remoteID`, metadati remoti su Supplier/Category/Product). |
| **TASK-041** | DONE | Modelli preflight + `SupabasePushApplyPlan` / dry-run tombstone-compliant **senza rete di scrittura**. |
| **TASK-042** | DONE | UI DEBUG preflight push dry-run in `OptionsView` + `SupabasePushPreflightViewModel` orchestrazione **read-only** remota per preview/preflight. |
| **TASK-043** | DONE | Baseline/fingerprint persistente locale (ultimo pull/apply **completo** riuscito); reader **latest valid**; gate preflight `blockedStaleOrPartialBaseline`, `blockedMissingBaseline`, tombstone conflict, account/schema fingerprint. |
| **Stato globale pre-attivazione** | IDLE | Ora **ACTIVE** con **TASK-044** in **PLANNING**. |

---

## 2. Riferimento Android / Supabase

| Riferimento | Stato | Uso per TASK-044 |
|-------------|--------|------------------|
| **TASK-068** | PARTIAL | Batch client-side bounded (es. 100) con fallback 50/25/singolo; remote refs aggiornati solo post-success remoto — **concetto utile**, ma **non** garanzia comportamento iOS; validazione live ancora aperta su Android. |
| **TASK-070** | DONE | Pattern retry head-of-line outbox — **non replicare outbox** su iOS in TASK-044. |
| **TASK-071** | DONE | RPC `record_sync_event` con mismatch noto — **TASK-044 non deve chiamare** `record_sync_event` **né** dipendere da `sync_events`. |

---

## 3. Ambito stretto TASK-044

| In scope | Fuori scope esplicito |
|----------|------------------------|
| Push reale **solo** `suppliers` / `categories` / `products` (mapping DTO/tabelle già allineati al progetto). | `ProductPrice` push. |
| Manuale, solo da UI DEBUG; conferma esplicita. | Delete/tombstone **outbound**. |
| Preflight/dry-run **prima** di write reale. | `sync_events` / `record_sync_event`. |
| Baseline TASK-043 come gate. | Outbox / dirty tracking persistente. |
| Batch piccolo bounded + fallback conservativo. | Automazione / background / realtime. |
| Idempotenza e retry sicuro senza doppie scritture incoerenti. | Modifiche SQL/RPC/RLS/migration. |

---

## 4. Architettura proposta

| Componente | Ruolo |
|------------|--------|
| **`SupabaseManualPushService`** *(o estensione controllata di un servizio esistente)* | Incapsula **solo** le operazioni di rete di scrittura catalogo consentite; **DI** / testabile; **nessun** outbox; ordinamento **supplier → category → product**. |
| **`SupabasePushApplyPlan`** *(TASK-041/042)* | Base per **prepare/preflight**; estendere **solo se necessario** per distinguere chiaramente fasi **prepare** vs **execute** e per aggregare batch **senza** ampliare categorie fuori scope. |
| **`SupabasePushPreflightViewModel`** | Orchestratore: **prepare/preflight** (no write) → stato UI → **confirm** → invoco **push** → stato **partial/completed/failed**; non sostituire il servizio di rete con logica UI duplicata. |
| **`OptionsView` (DEBUG)** | Unica superficie **entrypoint** utente per avviare preflight e, dopo conferma, push reale. |

### Separazione netta delle fasi (macchina a stati alto livello)
1. **Prepare / preflight**: lettura SwiftData, baseline TASK-043, sessione auth, generazione piano + conteggi; **zero** write remoto.
2. **Confirm**: `confirmationDialog` con conteggi e microcopy legali/safety.
3. **Push (write remoto)**: esecuzione batch bounded; gestione errori per-batch; payload conforme a **field ownership** (§4.3); **nessun** upsert «cieco».
4. **Commit identità locale (per entità)**: salvataggio `remoteID` / metadati TASK-040 **solo** dopo risposta remota di **successo** per quell’operazione; transazioni SwiftData piccole (§4.5).
5. **Read-back / verifica baseline**: dopo **tutto** il push pianificato **completato con successo**, eseguire **lettura remota** dei record toccati (o del sotto-catalogo minimo necessario) e **verificare** coerenza con quanto atteso — **solo allora** aggiornare la baseline TASK-043 come **valid** tramite il percorso già definito nel writer TASK-043 (nessuna shortcut che copi solo il piano locale).
6. Se il push è **partial** o **fallito**: baseline **non** diventa valid; se le **write** remote sono riuscite ma il **read-back fallisce**: stato finale **«remote write completed, baseline refresh failed / needs pull»** — **mai** etichetta «synced valid» o baseline valid finta.

### 4.1 Policy baseline post-push (read-back obbligatorio per «valid»)
- Dopo push **completo riuscito**, **non** marcare la baseline come valida **solo** copiando o derivando dal **piano locale** / fingerprint pre-write: quello non prova lo stato remoto effettivo.
- La baseline resta **valid** (run TASK-043 aggiornato nello stesso senso di un full pull/apply riuscito) **solo se**:
  - si esegue un **read-back remoto** mirato sui record **toccati** dal push (o su un subset catalogo **adequato e documentato**), **oppure**
  - le **righe** restituite da Supabase (insert/update returning / select successivi) sono **sufficienti e verificate** per ricostruire fingerprint/baseline coerenti con la policy TASK-043.
- Se il push è **partial** o **fallito**: la baseline **non** si aggiorna come valid (come già in CA-8); resta il run precedente valido o assenza di nuovo valid.
- Se **write remoto OK** ma **read-back / verifica baseline fallisce** (rete, RLS su select, mismatch imprevisto): stato terminale **`completedBaselineRefreshFailed`** (o equivalente localizzato) con azione consigliata **«needs pull»** / riprovare verifica — **non** «fully synced valid».

### 4.2 Policy conflitti e duplicati remoti (natural key / remoteID)
| Caso | Comportamento consigliato |
|------|---------------------------|
| Supplier/category **locale senza** `remoteID`, remoto con **stesso nome** | Se **match unico e verificabile** (una sola riga remota, criteri chiari): **link controllato** — aggiornare identità locale **solo dopo** verifica esplicita (stessa row, nessuna ambiguità). Se **ambiguo** (omonimie, più righe): **blocked** — nessun insert remoto; richiedere **pull + preflight** nuovo. |
| Product **senza** `remoteID`, remoto con **stesso barcode** | Stesso schema: match unico sicuro → **link** dopo verifica; altrimenti **blocked** + pull. |
| `remoteID` **locale presente** ma **record remoto non trovato** | **blocked** o **failure** chiaro: possibile stale locale, cambio tenant/schema, o dato cancellato — **non** assumere create; richiedere pull/riesame. |
| **Unique constraint** / conflitto su insert/update | **Non** creare duplicati remoti se una **natural key** (barcode, ecc.) **esiste già**: ramo **recuperabile** documentato in execution (es. transizione a link/update) solo se coerente con verifica; altrimenti **blocked**. **Mai** sovrascrivere un record remoto **ambiguo** o non identificato con certezza. |

### 4.3 Field ownership e payload (no overwrite cieco)
- Il push può includere **solo campi esplicitamente mappati** nei **DTO catalogo esistenti** (stesso schema note — niente colonne inventate).
- **Non** inviare `null` / clear per **campi non gestiti** da iOS nel modello di push: rischio di azzerare colonne remote che l’app non «possiede».
- **Non** sovrascrivere colonne remote **non rappresentate** nel modello SwiftData / non incluse nel piano: devono restare **preservate** lato remoto (update parziale / patch solo su chiavi consentite).
- **Create** e **update** devono usare **payload distinti** ove necessario (es. insert senza campi obbligatori solo lato default DB; update senza chiavi di insert-only).
- Ogni estensione campo in execution deve restare **allineata** ai DTO già presenti — nessun accrocchio generico « NSDictionary » verso Supabase.

### 4.4 Partial success, retry e stati UI
- In caso di **successo parziale**: i **`remoteID`** (e metadati coerenti) delle **singole entità già confermate** da Supabase possono essere **salvati localmente** in modo **sicuro** (per batch completati con risposta OK).
- La **baseline** **non** diventa **valid** finché l’intero flusso pianificato + read-back non sono soddisfatti (§4.1); partial ⇒ baseline precedente o stato «non aggiornata valid».
- **Retry**: riparte dallo **stato SwiftData già aggiornato** (include `remoteID` salvati); il piano successivo deve essere **idempotente** — **nessun** secondo create per entità già create con ID remoto noto (dedup esplicito in preflight/piano).
- **Stati UI** (enum / copy distinti) da supportare in planning/execution:
  - **`completed`**: write + read-back baseline OK.
  - **`completedBaselineRefreshFailed`**: write riuscita globalmente ma verifica baseline/read-back fallita → **needs pull** / retry verifica.
  - **`partial`**: alcune entità OK, altre no; baseline **non** valid.
  - **`failedBeforeWrite`**: errore prima di una write persistente (es. rete, guardrail) o **rollback logico** senza commit remoto.
  - **`blockedBeforeWrite`**: preflight/gate (account, baseline, conflitto) — CTA push disabilitata.

### 4.5 Atomicità locale (SwiftData / `ModelContext`)
- Aggiornamenti a **`remoteID`** e **metadati remoti** in **transazioni piccole** (save per batch o per entità, come ragionevole) **dopo** conferma remota; evitare commit enormi con metà stato obsoleto.
- **Non** salvare metadata «ottimistici» prima della risposta Supabase attesa per quella operazione.
- Gestire errori UI/task in modo che il **`ModelContext`** non resti in stato **incoerente** (es. rollback locale se un save batch fallisce a metà; documentare in execution i limiti SwiftData).
- In **partial success**, documentare **nel task/review** cosa può essere stato **salvato** localmente (quali entità hanno `remoteID`) e cosa **no** — per supporto utente e retry.

### 4.6 Reentrancy, doppio tap, concorrenza e background
- **Nessun** nuovo push se **preflight** o **push** è già **in corso** (`isRunning` / stato equivalente nel ViewModel).
- CTA push e azioni critiche **disabilitate** durante `running`; animazione/progress visibile.
- **ViewModel** con stato **running** esplicito; **no** avvio parallelo da **doppio tap** o gesture duplicate.
- **Nessun sync in background** introdotto da TASK-044: se l’app va in **background** durante push manuale, comportamento **conservativo** documentato: task può terminare in **partial** / **failure** / richiesta **retry** esplicita; **non** promettere completamento in background né baseline valid senza verifica.

---

## 5. Sequenza push consigliata (ordine operativo)

1. Verificare **sessione auth** Supabase valida (non anon se policy TASK-038 lo vieta post-login).
2. Leggere **baseline persistente** TASK-043 (**latest valid** run; account + schema fingerprint coerenti).
3. **Bloccare** se: baseline assente; **stale**/**partial**; schema mismatch; **account mismatch** vs baseline; **tombstone conflict**; **priceHistoryIncomplete** (se gate TASK-043/039 ancora applicabile al perimetro push); preflight con **conflitti** non risolvibili conservativamente (§4.2).
4. Generare **piano** da SwiftData confrontato alla baseline (riuso logica preflight esistente o sua evoluzione minima).
5. **Push suppliers** mancanti/modificati (create/update controllati — **no delete** remoto).
6. **Push categories** mancanti/modificate.
7. **Push products** con FK supplier/category **remoteID** risolti **prima** del batch prodotti.
8. **Batch** es. 50 o 100 (da fissare in execution con costanti centralizzate); **fallback** a batch minore o singolo record **solo** se utile, sicuro e coperto da test (stile ispirato a TASK-068, **senza** outbox).
9. Aggiornare identità locale **solo** dopo **successo remoto** verificato per quell’operazione (§4.4–4.5).
10. Se **qualsiasi** write fallisce o resta **partial** non riconciliabile: **non** marcare baseline valid; esporre stato UI §4.4; retry idempotente.
11. Se **tutte** le write previste hanno avuto successo: eseguire **read-back / costruzione baseline verificata** (§4.1); in caso di fallimento read-back → **`completedBaselineRefreshFailed`**, **non** synced valid.

---

## 6. Guardrail di sicurezza

- Blocco se preflight contiene **conflitti** che il piano classifica come non sicuri per write.
- Blocco se baseline **partial** / **stale** / **missing** o account Supabase **diverso** dalla baseline.
- Blocco se prodotto referenzia supplier/category **senza** `remoteID` risolvibile **al momento del push prodotti** (dopo aver tentato ordine supplier/category).
- Blocco o failure chiaro su **RLS** / **401/403** / errori **non recuperabili** (es. unique constraint non gestibile senza pull/link — comportamento da documentare per T-10).
- **No delete remoto**; no «upsert cieco» su colonne non possedute dal piano (cfr. §4.3).
- **No** `service_role` nel client.
- **Reentrancy / doppio tap / push concorrente**: cfr. §4.6 — un solo push manuale attivo; UI disabilitata durante `running`.
- **Logging tecnico**: evitare barcode/nome prodotto in chiaro **salvo** necessità debug locale esplicita e policy progetto; preferire hash/redazione in log.

---

## 7. UI DEBUG richiesta (`OptionsView`)

- **Stack UI**: **SwiftUI nativo**, coerente con **Typography** / **Section** / **List** / **labeledContent** già usati in **Opzioni**; nessuna webview o pattern estranei.
- **Posizione**: sotto la sezione **Supabase / DEBUG** esistente, **Card** o **Section** compatta (titolo chiaro es. *Push manuale catalogo*) — affiancata al flusso preflight TASK-042 senza duplicare tutta la diagnostica auth.
- **Contenuto sintetico (sempre visibile)**:
  - **Stato connessione** Supabase / account (sessione presente, scaduta, ecc. — riuso indicatori esistenti se possibile).
  - **Stato baseline** TASK-043 (assente / valid / stale / partial — allineato ai gate preflight).
  - **Ultimo preflight** (timestamp breve o «mai»; esito OK/blocked).
  - **Conteggi** supplier / category / product in **create** vs **update** (numeri da piano dry-run).
  - **Warning e blocchi** (1–2 righe + badge severità); dettagli lunghi in **disclosure** (`DisclosureGroup` / «Mostra dettagli») per non appesantire la card.
  - **Progress** durante push (progressivo testuale o `ProgressView` lineare) + fase corrente («Suppliers», «Categories», «Products», «Verifica baseline»…).
  - **Risultato finale** con **azione consigliata** (es. *Nessuna azione*, *Esegui pull completo*, *Riprova push*, *Controlla conflitti*).
- **CTA principale**: pulsante **«Esegui push su Supabase»** (o label localizzata equivalente) **abilitato solo** se: auth OK, baseline gate OK, preflight senza blocker, **non** `isRunning` — stesso gate del `confirmationDialog`.
- **`confirmationDialog`** prima della write reale: stessi conteggi della sequenza push / preflight (conteggi create/update supplier/category/product) + microcopy sicurezza.
- **Microcopy obbligatorio** (stringhe **IT / EN / ES / zh-Hans**):
  - **«Scrive su Supabase»** (o equivalente: comunica write remota).
  - **«Non invia storico prezzi»** / **«Non invia storico prezzi (ProductPrice)»**.
  - **«Non elimina record remoti»**.
  - **«Non attiva sync automatico»** (nessun background/realtime).
- **Stati UX** da mappare agli enum §4.4 + «idle» / «preflightReady» / «running» come necessario; copy distinto per **`completedBaselineRefreshFailed`** (read-back fallito).
- **Accessibilità**: `accessibilityLabel` coerenti su CTA e su riepilogo conteggi dove possibile (execution).

---

## 8. Criteri di accettazione

Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.

- [x] **CA-1**: Planning crea file task canonico **TASK-044** e aggiorna **MASTER-PLAN** a **ACTIVE** / **PLANNING** con task attivo **TASK-044** *(soddisfatto nel turno planning-only 2026-05-05)*.
- [x] **CA-2**: Scope documentato chiaramente: push reale **solo** supplier / category / products.
- [x] **CA-3**: **ProductPrice** fuori scope; pianificati **test e/o grep** anti-scope per assenza di push ProductPrice.
- [x] **CA-4**: `record_sync_event`, `.rpc` sync-event, **outbox** e **`sync_events`** fuori scope; grep/documentazione anti-scope in execution/review.
- [x] **CA-5**: **TASK-043** documentato come **prerequisito bloccante** — implementazione rispetta baseline persistente.
- [x] **CA-6**: **Account / auth gate** obbligatorio prima di preflight «go» e push.
- [x] **CA-7**: **Tombstone conflict** blocca push conservativamente.
- [x] **CA-8**: Push **parziale** / fallito **non** aggiorna baseline come **valid**; se **write** riuscita ma **read-back / verifica baseline** fallisce ⇒ stato **`completedBaselineRefreshFailed`** / **needs pull**, **mai** baseline valid o «fully synced» falso.
- [x] **CA-9**: **`remoteID`** (e metadati remoti coerenti TASK-040) aggiornati **solo dopo** successo remoto confermato.
- [x] **CA-10**: **Nessuna delete remota**.
- [x] **CA-11**: **Nessuna** nuova SQL/migration/RLS/RPC/dependency package oltre quanto già nel progetto per Supabase read/push minimale.
- [x] **CA-12**: **XCTest** pianificati per preflight, piano push, guardrail, read-back/failure modes e stati UI §4.4 *(matrice §9: T-1…T-24)*.
- [x] **CA-13**: In execution/review: **build Debug + Release** e **XCTest completo** richiesti con evidenza (comandi e risultati riportati nel file task o review).
- [x] **CA-14**: Localizzazioni **complete** IT / EN / ES / ZH-Hans per nuove stringhe.
- [x] **CA-15**: **Visual QA** manuale OptionsView DEBUG **consigliata** ma **non** sostituisce test automatici.
- [x] **CA-16**: **Grep / code review** anti-scope in evidenza execution/review: **nessun** push `ProductPrice`, **nessun** `record_sync_event`, **nessuna** tabella/workflow `sync_events`, **nessuna** outbox, **nessuna** delete remota nel perimetro implementato.
- [x] **CA-17**: **Controllo payload / client**: **nessun** `service_role`, **nessuna** RPC **sync-event** (incl. `record_sync_event`); payload conforme §4.3 (niente `null` su campi non posseduti).

---

## 9. Matrice test da pianificare (T-1 … T-24)

| ID | Scenario atteso |
|----|-------------------|
| **T-1** | Account non collegato → **blocked**. |
| **T-2** | Baseline mancante → **blocked**. |
| **T-3** | Baseline stale/partial → **blocked**. |
| **T-4** | Account mismatch baseline/session → **blocked**. |
| **T-5** | Piano vuoto → `completedNoWork` / no-op, nessuna write. |
| **T-6** | Supplier nuovo → push supplier; `remoteID` salvato post-success. |
| **T-7** | Category nuova → push category; `remoteID` salvato post-success. |
| **T-8** | Product nuovo con supplier/category remoti risolti → push product. |
| **T-9** | Product con supplier/category **senza** `remoteID` risolvibile → **blocked**. |
| **T-10** | Unique conflict remoto recuperabile per barcode/`remoteID` → comportamento **documentato** + test o stub che verificano il ramo scelto (conservativo). |
| **T-11** | Errore rete a metà batch → stato **partial** / **failure**; **nessun** aggiornamento baseline **valid**. |
| **T-12** | Errore RLS/auth → **blocked** / **failure** con messaggio chiaro. |
| **T-13** | Grep anti-scope: nessun `record_sync_event`, `sync_events`, outbox, push `ProductPrice`. |
| **T-14** | Presenza chiavi localizzazione nuove in **IT/EN/ES/zh-Hans**. |
| **T-15** | Regressione: suite / scenari **TASK-039 / 040 / 041 / 042 / 043** ancora **PASS** dopo modifiche. |
| **T-16** | Successo write completo ma **read-back / baseline refresh** fallisce → stato **`completedBaselineRefreshFailed`**; baseline **non** valid. |
| **T-17** | Successo write completo + **read-back verificato** → baseline **valid** aggiornata (percorso TASK-043). |
| **T-18** | Supplier/category/product remoto già esistente con **match unico** (natural key) → **link controllato**, **nessun** duplicato remoto. |
| **T-19** | Match remoto **ambiguo** (es. più righe stesso nome/barcode) → **blockedBeforeWrite** / blocked. |
| **T-20** | Update payload: **nessun** `null` / clear involontario su campi **non gestiti** da iOS (§4.3). |
| **T-21** | Partial success: `remoteID` salvato **solo** per entità con risposta OK; baseline **non** valid. |
| **T-22** | Retry dopo partial: **nessuna** seconda create per entità già creata (idempotenza piano). |
| **T-23** | Doppio tap / seconda invocazione durante `running` → **non** avvia due push paralleli. |
| **T-24** | Simulazione **background** / **cancellation** (task o errore UI): esito **conservativo**; **nessuna** baseline valid falsa; stato partial/failed documentato. |

---

## 10. File iOS probabili da toccare (execution futura)

- `OptionsView.swift`
- `SupabasePushPreflightViewModel.swift`
- Nuovo servizio o estensione: es. `SupabaseManualPushService.swift` *(write batch + read-back verifica; nome definitivo in execution)*
- DTO catalogo Supabase esistenti *(nessun campo inventato)*
- Reader/writer baseline TASK-043: integrazione **solo** per run **valid** dopo **read-back** verificato (§4.1); **nessun** writer su partial o `completedBaselineRefreshFailed`.
- `Models.swift` / modelli SwiftData **solo** se strettamente necessario (es. `lastSyncedAt` se già previsto)
- `Localizable.strings` (IT, EN, ES, zh-Hans)
- Target **XCTest** correlati

---

## 11. Fuori scope esplicito (ripetizione operativa)

Come § «Non inclus», più: **cleanup** dati remoti; **validazione live** distruttiva su catalogo grande; modifiche **Android**.

---

## 12. Rischi residui da documentare

- **TASK-068 Android PARTIAL**: comportamento bulk live **non** è contratto finale — mitigare con test iOS e dataset piccoli.
- Backend **`record_sync_event`** mismatch noto — mitigazione: **non usare** in TASK-044.
- Push reale **crea dati remoti**: richiede conferma utente e test su **dataset piccolo** prima di produzione.
- Se baseline **non** rappresenta ultimo stato remoto completo → **bloccare** (gate TASK-043).
- Read-back **fragile**: select post-write può fallire per **RLS** / rete / timeout — mitigare con stato **`completedBaselineRefreshFailed`** e messaggio **needs pull** (§4.1); test **T-16**.

---

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|--------|
| 1 | Push reale solo dopo **dry-run/preflight** + **confirmationDialog** | Push immediato da toggle | Sicurezza dati e coerenza con TASK-041/042. | attiva |
| 2 | **Nessun** `record_sync_event` / `sync_events` / outbox in TASK-044 | Parità Android event bus | Rischio TASK-071 e complessità; fuori scope esplicito utente. | attiva |
| 3 | Baseline TASK-043 **prerequisito**; niente «valid» dopo partial | Aggiornamento baseline ottimistico | Evita stato remoto/locale falsamente allineato. | attiva |
| 4 | Batch bounded con fallback conservativo | Un solo insert massivo | Affidabilità rete e limiti pratici; ispirazione controllata a TASK-068. | attiva |
| 5 | Entrypoint solo **DEBUG OptionsView** | Flusso produzione tab principale | Perimetro «manuale controllato» richiesto. | attiva |
| 6 | Baseline **valid** solo dopo **read-back** o equivalente verificato (§4.1) | Valid da piano locale post-write | Evita «synced» falso se remoto ≠ atteso. | attiva |
| 7 | **Field ownership** / payload create vs update (§4.3) | Upsert generico una tantum | Preserva colonne remote non possedute; no null accidentali. | attiva |
| 8 | Stati terminali UI espliciti incl. **`completedBaselineRefreshFailed`** | Solo «completed» generico | Utente sa se serve pull / retry verifica. | attiva |
| 9 | **Reentrancy** / un push alla volta (§4.6) | Concurrency implicita | Evita race e doppie write. | attiva |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Obiettivo
Portare l’ecosistema iOS da **preflight dry-run** (**TASK-041/042**) e **baseline persistente** (**TASK-043**) al **primo push reale** limitato a **supplier/category/product**, con **read-back obbligatorio** prima di dichiarare baseline **valid**, policy **conflitti/natural key**, **payload** senza overwrite cieco, stati UI **partial / completedBaselineRefreshFailed**, atomicità **SwiftData**, guardrail **reentrancy/background** — **senza** estendere il backend e **senza** outbox / `record_sync_event`.

### Analisi
Il codice iOS ha già: auth (**TASK-038**), pull/apply e identità remota (**TASK-039/040**), modelli di piano push dry-run (**TASK-041**) e UI/ViewModel preflight (**TASK-042**), più baseline valida/mismatch (**TASK-043**). Manca un **servizio di write** catalogo **delimitato**, **fase read-back** integrata con writer baseline TASK-043, e **test** T-1…T-24 + **grep** anti-scope (**CA-16/17**).

### Approccio proposto
1. Estendere il **ViewModel** per stati §4.4 + `isRunning` §4.6; card DEBUG compatta §7.
2. **`SupabaseManualPushService`**: write batch + **read-back** mirato (o uso di `returning` se sufficiente e verificabile); aggiornamento baseline **solo** su percorso valido TASK-043 dopo verifica.
3. **Preflight/piano**: incorporare regole §4.2 (link vs blocked) e idempotenza retry §4.4.
4. **Payload** §4.3: DTO esistenti; ramificazione create vs update dove serve.
5. **XCTest** + **grep** CA-16/17; build Debug/Release in review.

### File da modificare (execution — elenco provvisorio)
Come **§10**; nessun file SQL/migration.

### Rischi identificati
Come **§12**; in aggiunta: complessità **RLS** live non riproducibile in XCTest → prevedere **mock** o ambiente di test documentato **⚠️** se non eseguibile.

### Handoff → Execution
- **Prossima fase**: EXECUTION *(solo dopo **user override** esplicito — fase attuale del task resta **PLANNING** finché l’utente non autorizza)*
- **Prossimo agente**: CODEX / Cursor executor
- **Azione consigliata**: Leggere integralmente questo file + `MASTER-PLAN`; implementare servizio push + read-back baseline + wiring ViewModel/UI §7; test **T-1…T-24**; evidenze **CA-13** e **grep CA-16/17**; **non** SQL/RLS/RPC; aggiornare solo sezioni Execution/Handoff nel file task.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

*Execution completata il 2026-05-05 da Cursor / Codex executor. Task portato a REVIEW, non DONE.*

### Obiettivo compreso
Implementare il primo push reale Supabase manuale controllato da iOS, limitato a supplier/category/product, avviabile solo da UI DEBUG in `OptionsView`, con auth gate, baseline gate TASK-043, preflight/dry-run, confirmation dialog, snapshot stabile del piano confermato, batch bounded/fallback, update locale di `remoteID`/metadata solo dopo successo remoto confermato, baseline valid solo dopo read-back verificato, stati terminali distinti e retry idempotente. Durante sviluppo/test non e' stato eseguito alcun push live reale.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-044-supabase-manual-push-reale-controllato-ios.md`
- Supabase/auth/config/client e DTO/read-only esistenti: `SupabaseConfig.swift`, `SupabaseClientProvider.swift`, `SupabaseCatalogDTOs.swift`, `SupabaseCatalogService.swift`, `SupabaseAuthService.swift`
- Pull/apply/preview/preflight/baseline/remote identity: `SupabasePullApplyService.swift`, `SupabasePreviewModels.swift`, `SupabaseManualPushPreflightModels.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseCatalogBaselineModels.swift`, `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineWriter.swift`, `SwiftDataInventorySnapshotService.swift`, `Models.swift`
- UI e DI: `OptionsView.swift`, `ContentView.swift`, `iOSMerchandiseControlApp.swift`, `SupabasePushPreflightViewModel.swift`
- Localizzazioni: `en.lproj/Localizable.strings`, `it.lproj/Localizable.strings`, `es.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings`
- XCTest TASK-039/040/041/042/043 e nuovi test TASK-044 sotto `iOSMerchandiseControlTests/`

### Piano minimo
1. Aggiornare tracking da PLANNING a EXECUTION prima del codice, mantenendo il perimetro del task.
2. Riutilizzare preflight/baseline/remote identity gia' introdotti in TASK-039/040/041/042/043, senza architetture parallele.
3. Aggiungere un servizio testabile per push manuale supplier/category/product, con gateway Supabase isolato e mockabile.
4. Estendere preflight/ViewModel/UI DEBUG per piano congelato, confirmation dialog, reentrancy guard e stati terminali richiesti.
5. Coprire con XCTest la matrice TASK-044 e rieseguire build/test/check anti-scope.
6. Aggiornare tracking con handoff a REVIEW, senza marcare DONE.

### Modifiche fatte
- Aggiunto `SupabaseManualPushService.swift` con write reali limitate a `inventory_suppliers`, `inventory_categories`, `inventory_products`; nessun upsert cieco, nessuna delete, nessuna RPC; create/update separati e payload update senza `null` per campi non posseduti da iOS.
- Implementato batch bounded con fallback conservativo, commit locale di `remoteID`/metadata solo dopo risposta/verifica remota, read-back mirato con fingerprint remoto prima di aggiornare baseline valid tramite writer TASK-043.
- Esteso il piano preflight con supplier/category/product create/update/link, natural key match unico controllato, ambiguita' blocked, FK product risolte tramite remoteID o create/link gia' pianificati, baseline run id e fingerprint stabile del piano.
- Esteso `SupabasePushPreflightViewModel` con running/reentrancy guard, piano congelato per confirmation, verifica immediata pre-write contro piano corrente e stato `blockedBeforeWrite` se sessione/baseline/schema/dati locali cambiano.
- Aggiornata `OptionsView` DEBUG con stato connessione/baseline/preflight, conteggi create/update/link, errori in disclosure, progress, result/action e confirmation dialog con microcopy obbligatorio.
- Aggiornata DI in `ContentView` e `iOSMerchandiseControlApp` per fornire il servizio di push manuale.
- Estesa baseline TASK-043 con lookup canonical supplier/category e dati necessari al preflight TASK-044.
- Aggiornate localizzazioni IT/EN/ES/ZH-Hans.
- Aggiunti/aggiornati XCTest per servizio push, preflight, ViewModel, integrazione baseline e copertura localizzazioni.

### Check eseguiti
- ✅ ESEGUITO — Build Debug Simulator:
  `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`
  Esito: `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — Build Release Simulator:
  `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`
  Esito: `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — XCTest mirati TASK-044:
  `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseManualPushServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseManualPushPreflightTests -only-testing:iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests`
  Esito: `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — XCTest completo:
  `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`
  Esito: `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — Regressione TASK-039/040/041/042/043: coperta dallo XCTest completo PASS, inclusi test `SupabasePullApplyServiceTests`, `RemoteIdentityMetadataSwiftDataTests`, `SupabaseManualPushPreflightTests`, `SupabasePushPreflightViewModelTests`, `SupabaseCatalogBaseline*`.
- ✅ ESEGUITO — `git diff --check`: PASS, nessun output.
- ✅ ESEGUITO — Localizzazioni IT/EN/ES/ZH-Hans: `plutil -lint` su tutti i `Localizable.strings` PASS (`OK`) e XCTest `LocalizationCoverageTests` PASS.
- ✅ ESEGUITO — Coerenza planning/criteri: implementazione limitata a supplier/category/product, UI DEBUG, auth/baseline/preflight/confirmation/read-back/retry/reentrancy come richiesto.
- ✅ ESEGUITO — Anti-scope ProductPrice: grep mirato su servizio push TASK-044 senza occorrenze di `ProductPrice`, `product_prices`, `inventory_product_prices`.
- ✅ ESEGUITO — Anti-scope `record_sync_event` / `sync_events` / outbox: grep mirato su codice/test TASK-044 senza occorrenze operative.
- ✅ ESEGUITO — Assenza delete remota: grep su servizio/ViewModel/UI TASK-044 senza `.delete(` / `delete(`.
- ✅ ESEGUITO — Assenza `service_role`: grep mirato su codice/test TASK-044 senza occorrenze.
- ✅ ESEGUITO — Assenza SQL/migration/RLS/RPC nuove: `git status --short -- '*.sql' 'migrations' 'supabase' 'Supabase'` senza output; grep `.rpc` / `rpc(` su codice/test TASK-044 senza occorrenze.
- ✅ ESEGUITO — Controllo segreti/config reali: `SupabaseConfig.plist` non tracciato e non modificato; grep segreti sui file modificati TASK-044 senza output.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: build Debug/Release riuscite; Xcode emette un warning di metadata extraction AppIntents (`No AppIntents.framework dependency found`) non legato al codice TASK-044 e non e' possibile stabilire dal solo turno se fosse preesistente. Nessun warning Swift di compilazione TASK-044 osservato nei log finali.
- ❌ NON ESEGUITO — Visual QA manuale Simulator di `OptionsView`: non richiesta come gate obbligatorio dal task/utente in questo turno; UI coperta da build, ViewModel tests e localizzazioni. Da eseguire in review se si vuole evidenza visiva.

### Rischi rimasti
- Il primo push live reale resta intenzionalmente non eseguito in sviluppo/test: richiede azione manuale utente da UI DEBUG su dataset piccolo e baseline valida.
- Errori RLS/rete/read-back live possono produrre `completedBaselineRefreshFailed`; la baseline valid non viene aggiornata in quel caso e l'azione consigliata e' pull/verifica.
- SwiftData salva `remoteID`/metadata per entita' confermate: in caso di partial, il retry e' progettato per non duplicare create, ma l'utente dovra' ripartire da nuovo preflight.
- Visual QA manuale della card DEBUG non eseguita: follow-up di review consigliato, non blocco automatico secondo protocollo task UI.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: Claude / Reviewer
- **Stato task**: ACTIVE / REVIEW, non DONE
- **Sintesi handoff**: codice implementato, test automatici e check anti-scope eseguiti con esito positivo; nessun push live reale o automatico eseguito; nessun ProductPrice push, `record_sync_event`, `sync_events`, outbox, delete remota, SQL/RPC/RLS/migration, `service_role` o segreto/config reale introdotto.
- **Evidenze principali**: Build Debug PASS, Build Release PASS, XCTest mirati TASK-044 PASS, XCTest completo PASS, regressione TASK-039/040/041/042/043 PASS, `git diff --check` PASS, localizzazioni PASS, anti-scope/segreti PASS.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

*Review tecnica severa completata il 2026-05-05 da Codex reviewer/fixer su override esplicito dell'utente. Fix diretti piccoli/medi applicati in review; nessun stage/commit.*

### Verdetto review
**APPROVED_FIXED_DIRECTLY**

TASK-044 soddisfa il planning dopo i fix diretti. Il task viene chiuso in **DONE / Chiusura** e `MASTER-PLAN` va riallineato a **IDLE / nessun task attivo**.

### Problemi trovati
- Il preflight trattava alcuni record locali già linkati (`remoteID`) ma assenti dalla baseline come no-op, senza una verifica remota controllata sufficiente. Rischio: stato locale stale non bloccato in modo conservativo oppure retry dopo partial non abbastanza esplicito.
- Il servizio push poteva classificare male un errore dopo write remota già confermata ma prima del salvataggio/mapping locale, con rischio di stato `failedBeforeWrite` non conservativo; inoltre una create response non mappabile poteva essere ignorata invece di fallire in modo leggibile.
- `cancel()` del ViewModel poteva lasciare la UI in stato `running`.
- La microcopy safety sempre visibile comunicava il write remoto ma non includeva esplicitamente "Supabase" nella riga sintetica.

### Fix applicati
- Preflight: per record con `remoteID` e metadati remoti ma mancanti dalla baseline viene ora pianificato un **link verificato** (`dryRunLinkCandidate`) da confermare via read remoto prima di ogni write; se la verifica fallisce, il push termina conservativamente prima di nuove write. Senza metadati remoti sufficienti resta `blockedMissingBaseline`.
- Push service: aggiunti guard su count/mapping delle create response; update/create marcano la presenza di write remota confermata prima del commit locale; error handling terminale ora restituisce `partial` se c'e' stata write remota confermata.
- ViewModel: `cancel()` libera lo stato `running` e torna a `idle`.
- UI/localizzazioni: microcopy safety aggiornata per dichiarare esplicitamente "Scrive/Writes/Escribe/... Supabase".
- Test: aggiunti casi per verify-link conservativo, remoteID mancante in remoto, create response corrotta dopo write confermata, retry after partial senza duplicati, cancel running guard.

### File modificati in review
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushServiceTests.swift`
- `iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests.swift`
- `docs/TASKS/TASK-044-supabase-manual-push-reale-controllato-ios.md`
- `docs/MASTER-PLAN.md`

### Check eseguiti con risultato
- ✅ ESEGUITO — Build Debug Simulator:
  `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -quiet`
  Esito: PASS, exit code 0.
- ✅ ESEGUITO — Build Release Simulator:
  `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -quiet`
  Esito: PASS, exit code 0.
- ✅ ESEGUITO — XCTest mirati TASK-044:
  `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseManualPushServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseManualPushPreflightTests -only-testing:iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests`
  Esito: `** TEST SUCCEEDED **`.
- ✅ ESEGUITO — XCTest completo:
  `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -quiet`
  Esito: PASS, exit code 0.
- ✅ ESEGUITO — Regressione TASK-039/040/041/042/043: coperta da XCTest completo PASS.
- ✅ ESEGUITO — `git diff --check`: PASS, nessun output.
- ✅ ESEGUITO — `plutil -lint` localizzazioni IT/EN/ES/ZH-Hans: tutti i file `OK`.
- ✅ ESEGUITO — Anti-scope ProductPrice push: grep mirato sul servizio push senza occorrenze operative; l'unica occorrenza rilevata nei test e' `ProductPrice.self` nello schema SwiftData della fixture.
- ✅ ESEGUITO — Anti-scope `record_sync_event`, `sync_events`, outbox, `.rpc` sync-event, delete remota, `service_role`: grep mirati senza occorrenze nel perimetro TASK-044.
- ✅ ESEGUITO — SQL/migration/RLS/RPC nuove e config/segreti reali tracciati: nessun file SQL/migration/Supabase config reale modificato o tracciato; nessun `SupabaseConfig.plist`, `.env`, `service_role`, secret/secrets in `git ls-files`.
- ✅ ESEGUITO — `project.pbxproj`: nessun diff; progetto con filesystem-synchronized root groups, quindi i nuovi file sono coerenti senza reference manuali superflue.
- ✅ ESEGUITO — Controllo untracked attesi/non attesi: attesi `docs/TASKS/TASK-044...md`, `SupabaseManualPushService.swift`, `SupabaseManualPushServiceTests.swift`; nessun segreto/config reale untracked rilevato dal controllo mirato.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: build/test PASS; un warning AppIntents metadata (`No AppIntents.framework dependency found`) era visibile nei log Xcode e non e' attribuibile a TASK-044. Nessun warning Swift TASK-044 osservato nei log finali quiet.
- ⚠️ NON ESEGUIBILE — Push live Supabase reale: volutamente non eseguito per istruzione utente e per sicurezza dati.
- ❌ NON ESEGUITO — Visual QA manuale Simulator di `OptionsView`: non richiesta come gate obbligatorio; coperti build, ViewModel tests e localizzazioni.

### Conferma anti-write live Supabase
Nessun push Supabase live reale eseguito in review. Nessun cleanup remoto eseguito.

### Conferma anti-scope
Confermato: no ProductPrice push, no storico prezzi remoto, no delete remota, no tombstone outbound, no `record_sync_event`, no `.rpc` sync-event, no `sync_events`, no outbox/dirty queue, no sync automatico/background/realtime, no SQL/migration/RLS/RPC nuove, no `service_role`, no segreti/config reali tracciati, no modifiche Android.

### Rischi residui
- Prima validazione live reale resta da fare manualmente su dataset piccolo e baseline valida, in un task/turno dedicato.
- In ambiente live RLS/rete/read-back possono ancora produrre `completedBaselineRefreshFailed`; comportamento previsto e conservativo.
- Il warning AppIntents metadata resta non attribuito a TASK-044 e non e' stato corretto per evitare scope creep.
- Visual QA manuale OptionsView DEBUG resta follow-up consigliato, non blocker del task.

### Stato finale task
**DONE / Chiusura** su override esplicito utente dopo review approvata con fix diretti.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

*Non avviata.*

---

## Chiusura

### Conferma utente
- [x] Utente ha confermato/istruito la chiusura in DONE se la review tecnica risultava OK dopo eventuali fix diretti (override esplicito 2026-05-05).

### Follow-up candidate
- ProductPrice push remoto; `record_sync_event` / event bus; outbox/realtime; tombstone outbound/delete remoto — **fuori scope TASK-044**, da task futuri.

### Riepilogo finale
TASK-044 chiuso con esito **APPROVED_FIXED_DIRECTLY**. Implementato e verificato push manuale controllato Supabase iOS limitato a supplier/category/product, baseline-gated TASK-043, con piano congelato, confirmation, write bounded, read-back prima della baseline valid, stati terminali conservativi e test automatici mirati/completi PASS. Nessun push live reale eseguito da sviluppo/review.

### Data completamento
2026-05-05
