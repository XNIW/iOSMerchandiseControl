# TASK-079 — Push catalogo guidato (Release)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-079 |
| **Titolo** | Push catalogo guidato — invio manuale catalogo locale verso Supabase dopo conferma |
| **File task** | `docs/TASKS/TASK-079-supabase-guided-catalog-push-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Claude / Reviewer |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 15:52 -0400 — REVIEW/FIX/CHIUSURA completata su override utente; fix pre-write auth/session recheck applicato; build/test/lint/grep PASS; TASK-079 chiuso DONE / Chiusura. |
| **Ultimo agente** | Codex / Reviewer (Claude review override) |

## Dipendenze

- **Dipende da:** **TASK-078 DONE / Chiusura** (pull apply locale guidato: staging `SyncPreview`, sheet **Rivedi**, conferma, **Aggiorna questo dispositivo**, summary); **TASK-077** (sheet UX); **TASK-076** (audit gap); infrastruttura storica **TASK-039…TASK-044+** per push/preflight/baseline.
- **Sblocca:** percorso Release completo «cloud ↔ dispositivo» sul solo catalogo prima di **TASK-080** (ProductPrice); allineamento naturale con **TASK-082** (conflitti) e **TASK-081** (drain outbox) come task separati.

## Scopo (planning)

Documentare in modo **repo-grounded** come portare in **Release** l’invio catalogo locale verso Supabase dopo conferma, riusando servizi esistenti, senza questo turno modificare codice applicativo.

## Criteri di accettazione (planning-only)

- [x] Obiettivo e perimetro TASK-079 coerenti con MASTER-PLAN e con TASK-078 completato.
- [x] Inventario servizi iOS + schema Supabase (lettura clone locale) senza inventare tabelle/colonne.
- [x] Gap analysis con etichette READY / PARTIAL / MISSING / BLOCKED / OUT OF SCOPE.
- [x] UX Release proposta senza jargon vietato; decisioni **D79-xx**, **D79-UX**, **D79-EFF**; micro-slice **S79-a…S79-g**; sezione **Review planning**; test matrix; rischi; DoR/DoD planning; handoff **READY FOR PLANNING REVIEW** / **NON READY FOR EXECUTION**.

## Non incluso (perimetro esplicito)

- **TASK-080:** ProductPrice full sync / storico prezzi push.
- **Android**, modifiche backend, migration SQL, `db push`, smoke live reale in questo planning turn.
- Sync automatica, `Timer`, `BGTask`, Realtime, worker, polling, drain outbox Release (**TASK-081**).
- Risoluzione policy conflitti strutturata oltre quanto gia’ implicito nei guard esistenti (**TASK-082**).
- Dichiarazione **TASK-079 DONE** o apertura **TASK-080** da questo file.

---

## 1. Obiettivo

Abilitare in **Release** l’invio **manuale e confermato** del **solo catalogo** locale (`Product`, `Supplier`, `ProductCategory` e relativi link remoto) verso Supabase, riusando dove possibile `SupabaseManualPushPreflightService` / `SupabaseManualPushService`, con:

- **batching** bounded e gestione **successo parziale**;
- **retry manuale** e stati terminali comprensibili;
- **summary user-facing** coerente con TASK-074/078 (senza promesse eccessive);
- **aggiornamento locale del baseline** dopo write **solo se** il percorso esistente lo giudica sicuro (gia’ modellato nel servizio push come refresh + read-back).

---

## 2. Stato attuale iOS (repo-grounded)

| Area | File / componente | Evidenza |
|------|---------------------|----------|
| **Release card** | `SupabaseManualSyncReleaseFactory` | Costruisce `SupabaseManualSyncViewModel` con coordinator **dry-run**, preview remota via `SupabaseManualSyncPullPreviewAdapter`, **Pull apply**: `SupabasePullApplyService` + `ModelContext`. **Non** inietta `SupabaseManualPushService` ne’ preflight push Release. |
| **Coordinator** | `SupabaseManualSyncCoordinator` | Con `remotePreviewProvider != nil`, dopo `.remotePreview` esce con `finalizeRemotePreviewOnly`: **nessuna** fase `.catalogPush` reale. Con provider nil e dry-run classico, `.catalogPush` e’ solo **simulata** da `SupabaseManualSyncReleaseDryRunPhaseSimulator`. |
| **Dry-run Release** | `SupabaseManualSyncReleaseDryRunPhaseSimulator` | `simulateCatalogPushPhase()` ⇒ sempre `.completed` (nessuna rete). |
| **Push rete** | `SupabaseManualPushService` | `execute(plan:context:ownerUserID:)` ordina supplier → category → product; `maxBatchSize` default **50**; stati `SupabaseManualPushTerminalStatus`: `completed`, `completedBaselineRefreshFailed`, `partial`, `failedBeforeWrite`, `blockedBeforeWrite`; dopo write tenta read-back + `SupabaseCatalogBaselineWriter.commitLatestBaseline`. |
| **Remote client** | `SupabaseManualPushRemoteClient` | Tabelle `inventory_suppliers`, `inventory_categories`, `inventory_products`; colonne allineate a snake_case API (`owner_user_id`, `updated_at`, `deleted_at`, …). |
| **Preflight** | `SupabaseManualPushPreflightService`, `ManualPushPlan` | Genera piano con candidati create/update/link e blockers; usato dal pending snapshot Release (**TASK-069**) e dal flusso DEBUG. |
| **Preflight UI (DEBUG)** | `SupabasePushPreflightViewModel`, `OptionsView` (`#if DEBUG`) | Sezione avanzata: preflight, conferma, push reale con `manualPushService` passato dalla app; **non** esposta in build Release utente finale. |
| **Baseline** | `SupabaseCatalogBaselineReader` / `SupabaseCatalogBaselineWriter` | Gate Release (`SupabaseManualSyncReleaseBaselineGate`) e refresh post-push gia’ nel servizio push. |
| **Auth** | `SupabaseAuthViewModel`, `SupabaseManualSyncReleaseAuthGate` | Sessione signed-in come prerequisito coerente con RLS `owner_user_id = auth.uid()`. |
| **App DI** | `iOSMerchandiseControlApp.swift` | `manualPushService = SupabaseManualPushService(clientProvider:)` in `SupabaseAppDependencies`; **non** collegato alla factory Release. |
| **Outbox (codice)** | `SyncEventOutboxEnqueueService` | Modella `catalogManualPush(result:)` per metadata outbox; **nessuna** chiamata diretta trovata da `SupabaseManualPushService` / file `*Push*.swift` nel modulo app (enqueue resta integrazione esplicita futura / **TASK-081**). |

---

## 3. Riferimento TASK-078 (pull apply locale guidato)

- **Gia’ implementato:** dopo **Controlla cloud**, la preview remota completa resta in **staging volatile** (`remotePreviewStaging` / `stagedPreviewForLocalApply`); la sheet **Rivedi** mostra aggregati privacy-safe; l’utente conferma; **Aggiorna questo dispositivo** esegue `prepareApplyPlan` + `apply(plan:)` su SwiftData **solo catalogo** (`applyStockQuantity` false nel perimetro Release).
- **Non coperto da TASK-078:** mutazioni **verso Supabase** (push); coordinator Release non esegue push reale; `guidedManual` resta non usato per questo percorso.

TASK-079 e’ il complemento **dispositivo → cloud** sullo stesso scaffolding UX (Controlla / Rivedi / Conferma / azione mutativa / Summary), con copy dedicato all’**invio** invece che all’**aggiornamento locale**.

---

## 4. Inventario servizi iOS (push catalogo e dintorni)

| Componente | Ruolo per TASK-079 | Note |
|------------|-------------------|------|
| **Coordinator manual sync** | **PARTIAL** | Modella fasi incluso `.catalogPush`; in Release reale oggi **non** invoca `SupabaseManualPushService`. |
| **ViewModel Release** | **PARTIAL** | `SupabaseManualSyncViewModel` governa pull staging + apply locale; **manca** staging/gating analogo per piano push + esecuzione push. |
| **Factory Release** | **PARTIAL** | Non passa `manualPushService` ne’ adapter push; estendibile con DI minimale in execution. |
| **Servizi push** | **READY** (`SupabaseManualPushService`, preflight, piano) | Logica batch/partial/baseline refresh gia’ presente; da incollare dietro conferma Release. |
| **Baseline / auth / session** | **READY** | Gate baseline Release + lettura baseline push; `ownerUserID` da sessione. |
| **Outbox / sync_events** | **PARTIAL / differito** | Tabella e RPC esistono lato Supabase; enqueue catalogo **non** obbligatorio per TASK-079; drain **TASK-081**. |
| **Summary user-facing** | **PARTIAL** | Pattern TASK-074/078 estendibile con messaggi su invio parziale / baseline refresh fallito (gia’ enum lato `SupabaseManualPushResult`). |
| **Test esistenti** | **READY** (layer isolato) | `SupabaseManualPushServiceTests`, `SupabasePushPreflightViewModelTests`, baseline reader/writer tests, outbox enqueue tests per shape `catalogManualPush`. |

---

## 5. Verifica schema Supabase (solo lettura, repo `MerchandiseControlSupabase`)

Fonte primaria per il catalogo produzione: migrazioni sotto `supabase/migrations/`, non i file `sql/00x_*.sql` marcati come bozza/commentati.

### 5.1 Tabelle equivalenti a Product / Supplier / Category

| Tabella Postgres | Colonne rilevanti (non esaustivo) | Ownership / sessione |
|------------------|-----------------------------------|----------------------|
| `inventory_suppliers` | `id`, `owner_user_id` → `auth.users`, `name`, `updated_at`, `deleted_at` (TASK-019 tombstone) | RLS: `auth.uid() = owner_user_id` |
| `inventory_categories` | stesso pattern | idem |
| `inventory_products` | `barcode`, `item_number`, `product_name`, `second_product_name`, prezzi, `supplier_id`, `category_id`, `stock_quantity`, `updated_at`, `deleted_at` | idem; unico parziale su `(owner_user_id, barcode)` WHERE `deleted_at IS NULL` |

### 5.2 Allineamento con il client iOS

`SupabaseManualPushRemoteClient` usa gli stessi nomi tabella e subset colonne coerente con la migrazione **TASK-013** + **TASK-019** (`deleted_at`, indici unici parziali, trigger anti-update su tombstone).

### 5.3 RPC / funzioni

- **`record_sync_event`** (migrazione sync_events): presente per dominio catalogo/prezzi; **non** richiesto dal codice `SupabaseManualPushService` letto per il push catalogo; integrazione eventuale legata a outbox (**TASK-081** / politica prodotto), non parte minima TASK-079.

### 5.4 Cosa non si inventa

Nessuna nuova tabella o colonna assunta oltre quanto sopra citato dai file letti.

---

## 6. Gap analysis (READY / PARTIAL / MISSING / BLOCKED / OUT OF SCOPE)

| Voce | Classificazione | Motivazione sintetica |
|------|-----------------|------------------------|
| Esecuzione push rete + batch + partial | **READY** | `SupabaseManualPushService` gia’ implementato. |
| Preflight / piano sendable | **READY** | `SupabaseManualPushPreflightService` + `ManualPushPlan`. |
| Baseline post-push + read-back | **READY** | Dentro `execute` del servizio push. |
| Wiring Release ViewModel + conferma UX | **MISSING** | Staging piano push, stati UI, CTA «invio» non collegati alla card Release. |
| Coordinator opzionale vs azione ViewModel | **PARTIAL** | TASK-078 ha preferito ViewModel per apply locale; stessa linea probabile per push (da confermare in planning review) per evitare `guidedManual`. |
| Enqueue `sync_events` dopo push | **PARTIAL / opzionale** | Codice enqueue pronto; non invocato dal servizio push; **TASK-081** per drain Release. |
| Policy conflitti avanzata (LWW, merge) | **BLOCKED per TASK-079** | Rimandata a **TASK-082**; TASK-079 deve rispettare blockers/hard fail gia’ nel preflight senza «risoluzione magica». |
| ProductPrice push | **OUT OF SCOPE** | **TASK-080**. |
| Push UI solo DEBUG | **READY** oggi, **MISSING** in Release | DEBUG `SupabasePushPreflightViewModel` + `OptionsView`. |

---

## 7. UX Release proposta (senza gergo tecnico)

**Flusso obbligatorio (macro):**

1. **Controlla cloud** — come oggi (read-only / diff / anticipazione modifiche lato cloud).  
2. **Rivedi** — sheet esistente: sezioni comprensibili; chiarire cosa arriva dal cloud e cosa andra’ **verso il cloud** (linguaggio naturale).  
3. Se ci sono modifiche **remote** da applicare: **Aggiorna questo dispositivo** (TASK-078), con conferma **dedicata** al solo pull apply.  
4. Se ci sono modifiche **locali** sicure da inviare: dopo il passo 3 se necessario, procedere verso **Invia modifiche al cloud** (CTA primaria scelta; forma compatta **Invia al cloud** solo dove lo spazio UI lo richiede), con conferma **separata**, vedi **D79-UX-02**.  
5. **Invio** (verso Supabase) — dopo conferma; feedback alto livello.  
6. **Summary** — recap onesto: completato / parzialmente completato / non inviato; **Riprova** dove applicabile.

**Termini da non mostrare in Release:** outbox, RPC, `sync_events`, baseline (come parola), payload, nomi tipi (`ManualPushPlan`, ecc.).

Dettaglio flusso a **uno step alla volta**, ordine **pull apply → push** quando coesistono remote+local, CTA user-facing definitiva e divieti copy sono nella sezione **Review planning** sotto.

---

## Review planning — UX, efficienza e confini execution

### 1. Decisione UX principale

Per la futura **EXECUTION** la UX deve essere **guidata a uno step singolo per volta**, non una sync generica «tutto insieme».

**Flusso Release preferito:**

1. **Controlla cloud**  
2. **Rivedi**  
3. Se ci sono modifiche **remote** applicabili: **Aggiorna questo dispositivo** (come TASK-078)  
4. **Poi**, solo se ci sono modifiche **locali** sicure da inviare: procedere verso **Invia modifiche al cloud**  
5. **Conferma** esplicita (non condivisa tra pull apply e push)  
6. **Invio** (catalogo verso Supabase)  
7. **Summary** finale onesto  

Se sono presenti **sia** modifiche remote **sia** modifiche locali, il default UX e’: **prima Aggiorna questo dispositivo, poi Invia modifiche al cloud**.

**Motivo:** riduce conflitti, evita confusione tra pull e push, resta coerente con TASK-078.

### 2. CTA e copy UI

**CTA push scelta (user-facing):** **«Invia modifiche al cloud»**. Usare **«Invia al cloud»** solo come fallback compatto per chip/menu/spazi stretti.

**Non usare in copy visibile:** «Sincronizza tutto», «Full sync», «Push catalogo», «RPC», «outbox», «sync_events», «baseline», «payload», «DTO».

**Card `OptionsView`:** resta **compatta**; dettagli lunghi solo nella sheet **Rivedi**.

**Sheet (coerenza TASK-077 / TASK-078):**

- Header compatto  
- Sezioni chiare  
- Icone **SF Symbol** semantiche  
- Footer con **CTA primaria** e **Annulla**  
- **Una sola** CTA `.borderedProminent` per stato  
- **VoiceOver / accessibilità:** label chiare, non affidarsi solo alle icone  

### 3. Efficienza tecnica

Non pianificare un **invio cieco di tutto il catalogo** se il codice consente un **delta** sicuro.

**Preferenza tecnica (execution):**

- preflight push **read-only** (`SupabaseManualPushPreflightService` + stati SwiftData / baseline)  
- **push plan volatile** in memoria dopo preflight  
- conferma utente **dedicata** al push  
- **batch bounded** (es. `maxBatchSize` gia’ in `SupabaseManualPushService`)  
- **partial success** esplicito nel summary  
- **retry manuale** mirato  
- summary **user-facing**  
- **baseline refresh** post-write **solo** se il servizio lo verifica sicuro (gia’ nel flusso `execute`: read-back + `commitLatestBaseline` quando possibile)

**Nota repo-grounded:** oggi il percorso e’ basato su **`ManualPushPlan`** con **candidati** create/update/link (`writeCandidates`), non su un dump integrale del catalogo: classificazione **READY — delta consapevole** rispetto a «full blind push». Se in execution emergesse divergenza (es. piano che coinvolge sempre l’intero dataset senza filtro), va documentata come scelta **consapevole** o rilassata a **PARTIAL**, non occultata.

### 4. Decisioni aggiuntive (D79-UX e D79-EFF)

Le tabelle sotto integrano la sezione **§8** (`D79-xx`). Qui: vincoli UX ed efficienza espliciti per review/execution.

| ID | Decisione |
|----|-----------|
| **D79-UX-01** | Una sola CTA primaria per stato. |
| **D79-UX-02** | Pull apply e push catalogo **non** nella stessa azione di conferma. |
| **D79-UX-03** | Se remote+local coesistono: prima **Aggiorna questo dispositivo**, poi **Invia modifiche al cloud**. |
| **D79-UX-04** | Riusare stile sheet TASK-077 / TASK-078. |
| **D79-UX-05** | Summary **non** deve dire «tutto sincronizzato» se ci sono partial / failure / skipped. |
| **D79-UX-06** | Errori correggibili: copy tipo **«Da correggere»**, non errore tecnico generico. |
| **D79-UX-07** | `OptionsView` leggera; dettagli nella sheet. |
| **D79-UX-08** | UI accessibile: label chiare, copy non tecnico. |
| **D79-UX-09** | In caso di scelta tra più copy validi, preferire **«Invia modifiche al cloud»** nella CTA primaria perché spiega meglio che non viene inviato “tutto” in modo cieco. |
| **D79-UX-10** | La Release card deve mostrare solo lo stato principale e il prossimo passo; conteggi dettagliati e motivi di blocco vanno nella sheet, non nella card. |
| **D79-UX-11** | Durante invio/apply, disabilitare CTA e azioni concorrenti per evitare doppio tap, doppio push o cambio stato mentre il piano è in uso. |
| **D79-UX-12** | Se l’utente non è autenticato o la sessione scade, mostrare un messaggio naturale tipo **«Accedi per inviare al cloud»**, senza errori tecnici. |
| **D79-UX-13** | Dopo success/failure, mantenere un summary stabile finché l’utente non avvia un nuovo controllo; evitare snackbar effimere come unico feedback. |
| **D79-UX-14** | Stato zero-change: se non ci sono modifiche locali candidate, mostrare **«Nessuna modifica locale da inviare»** e non mostrare CTA mutativa. |
| **D79-UX-15** | Stato all-blocked: se tutte le righe sono bloccate, mostrare solo **Da correggere** + motivi; la CTA **Invia modifiche al cloud** resta disabilitata. |
| **D79-UX-16** | Se partial success crea qualche record remoto ma fallisce dopo, il summary deve distinguere **Inviati**, **Non inviati**, **Da riprovare**; non chiudere automaticamente la sheet senza recap. |
| **D79-UX-17** | In caso di baseline refresh fallito dopo write riuscita, mostrare successo prudente: modifiche inviate, stato locale da ricontrollare con nuovo **Controlla cloud**. |
| **D79-UX-18** | La sheet futura deve distinguere visivamente i tre gruppi principali con gerarchia coerente: **Pronto da inviare**, **Attenzione**, **Da correggere**. |
| **D79-UX-19** | Usare icone SF Symbol solo come supporto semantico: `icloud.and.arrow.up`, `checkmark.circle`, `exclamationmark.triangle`, `xmark.octagon`, senza dipendere dal colore come unico segnale. |
| **D79-UX-20** | Evitare testo lungo nei pulsanti: la CTA resta breve; spiegazioni lunghe vanno nel corpo della sheet o nel summary. |
| **D79-UX-21** | Il summary finale deve restare visibile finché l’utente non lo chiude o avvia un nuovo controllo; non sostituirlo solo con toast/snackbar temporanee. |

| ID | Decisione |
|----|-----------|
| **D79-EFF-01** | Batch bounded **conservativi** per dataset grande. |
| **D79-EFF-02** | Partial success **visibile** nel summary. |
| **D79-EFF-03** | Retry manuale solo su **elementi falliti** se il modello risultati lo supporta. |
| **D79-EFF-04** | Idempotenza **verificata** (test/review) prima dell’execution. |
| **D79-EFF-05** | Baseline refresh post-write **solo se** sicuro (come da servizio). |
| **D79-EFF-06** | **Nessun** drain outbox implicito in TASK-079. |
| **D79-EFF-07** | ProductPrice escluso → **TASK-080**. |
| **D79-EFF-08** | Conflitti **timestamp** esclusi → **TASK-082**. |
| **D79-EFF-09** | Invalidare il push plan volatile dopo nuovo **Controlla cloud**, cambio login/sessione, modifica SwiftData locale rilevante, apply TASK-078 riuscito, cancel, success o failure terminale. |
| **D79-EFF-10** | Evitare doppia preparazione costosa: usare preflight leggero per UI eligibility e preparazione completa solo al momento della conferma, se il codice esistente lo consente. |
| **D79-EFF-11** | Bloccare reentrancy con stato `isSending`/equivalente: una sola operazione push alla volta. |
| **D79-EFF-12** | Prima di scrivere remoto, verificare che auth/sessione e ownerUserID siano ancora validi; se non lo sono, fallire prima della write con copy user-facing. |
| **D79-EFF-13** | Per dataset grandi, limitare preview dettagliata a conteggi e piccoli esempi; non introdurre lista completa o ricerca dentro TASK-079. |
| **D79-EFF-14** | Non duplicare la logica DEBUG: estrarre o riusare solo adapter/servizi necessari, mantenendo la UI Release nativa e minimale. |
| **D79-EFF-15** | Associare al push plan volatile un token/fingerprint dello snapshot locale usato per generarlo; se cambia prima della conferma, invalidare e richiedere nuovo preflight. |
| **D79-EFF-16** | Prima della write remota, ricontrollare zero-change/all-blocked per evitare chiamate rete inutili. |
| **D79-EFF-17** | Se `completedBaselineRefreshFailed` ritorna dal servizio, non ripetere automaticamente la write: proporre nuovo controllo o retry controllato in base al risultato. |
| **D79-EFF-18** | Evitare che un retry riusi un piano parziale vecchio: ogni retry manuale deve ripartire da preflight o da un sottoinsieme fallito esplicitamente verificato. |

### 4-bis. Mapping risultati push → UX Release

La futura execution deve mappare gli esiti reali del servizio in stati UI stabili e non ambigui.

| Esito servizio / situazione | Stato UI consigliato | CTA successiva | Copy sintetico |
|-----------------------------|----------------------|----------------|----------------|
| `completed` | Successo | `Controlla cloud` opzionale | `Modifiche inviate al cloud.` |
| `completedBaselineRefreshFailed` | Successo prudente | `Controlla cloud` | `Modifiche inviate. Ricontrolla il cloud per aggiornare lo stato locale.` |
| `partial` | Parziale | `Riprova` | `Alcune modifiche sono state inviate. Altre richiedono un nuovo tentativo.` |
| `blockedBeforeWrite` | Bloccato | nessuna CTA mutativa | `Correggi gli elementi indicati prima di inviare.` |
| `failedBeforeWrite` | Fallito senza scrittura | `Riprova` | `Non sono riuscito a iniziare l’invio. Nessuna modifica è stata inviata.` |
| Errore durante batch successivi | Parziale o fallito, secondo risultato servizio | `Riprova` dopo nuovo preflight | `Invio interrotto. Controlla il riepilogo prima di riprovare.` |
| Piano stale prima della conferma | Stale | `Controlla cloud` | `I dati sono cambiati. Esegui di nuovo il controllo.` |
| Zero-change | Nessuna azione | nessuna CTA mutativa | `Nessuna modifica locale da inviare.` |
| All-blocked | Da correggere | nessuna CTA mutativa | `Ci sono elementi da correggere prima dell’invio.` |

Regola importante: dopo una write remota riuscita, anche parziale, non promettere rollback automatico. Il recovery deve passare da summary, nuovo preflight e retry manuale.

### 5. Casi di scelta gia’ decisi (planning)

| Situazione | Scelta preferita | Motivo UX |
|------------|------------------|-----------|
| Remote + local presenti | Prima **Aggiorna questo dispositivo**, poi **Invia modifiche al cloud** | Riduce conflitti; ordine chiaro |
| Push parziale | Mostrare **Inviati / Da riprovare / Da correggere** (o equivalente naturale) | L’utente capisce il prossimo passo |
| Supplier/category mancanti | Creare solo se il **servizio preesistente** lo supporta nel piano; altrimenti **bloccare** quelle righe | Evita dati orfani |
| Barcode duplicati | **Bloccare** quelle righe; copy **«Da correggere»** | Evita mismatch cloud |
| Errore rete | **Retry manuale**; nessun loop automatico | Coerente con sync **manuale** |
| Conflitto timestamp | **Non** risolvere in TASK-079 | **TASK-082** |
| ProductPrice presente | **Non** includere | **TASK-080** |
| Nessuna modifica locale candidate | Mostrare **Nessuna modifica locale da inviare**; nessuna write | Evita azioni vuote o finte |
| Tutte le righe bloccate | CTA disabilitata; mostrare **Da correggere** | Evita fallimenti prevedibili |
| Baseline refresh fallisce dopo write riuscita | Summary prudente + nuovo **Controlla cloud** | Evita doppia write inutile |
| Piano push diventa stale prima della conferma | Invalidare e richiedere nuovo controllo/preflight | Evita invio su snapshot vecchio |
| Utente chiude sheet durante invio | Disabilitare dismiss o mantenere stato fino a terminale | Evita incertezza operativa |

### 6. Micro-slice ottimizzate (S79-a…S79-g)

Ogni slice resta **piccola** e **testabile**.

| Slice | Contenuto |
|-------|-----------|
| **S79-a** | Planning review finale |
| **S79-b** | Preflight push read-only |
| **S79-c** | Push plan volatile (staging sessione) |
| **S79-d** | Review sheet Release (pull vs push, ordine consigliato) |
| **S79-e** | Push manuale confermato |
| **S79-f** | Summary e retry manuale |
| **S79-g** | Baseline refresh post-write controllato (solo se sicuro) |

### 7. Test matrix aggiuntiva (oltre §10)

Pianificare in XCTest / controlli statici:

- **ViewModel:** CTA che commutano in modo coerente tra **Controlla cloud** / **Aggiorna questo dispositivo** / **Invia modifiche al cloud** / **Riprova**.  
- **ViewModel:** scenario **remote+local** → ordine consigliato **non** ambiguo (non «sync unica» generica).  
- **Coordinator fake:** piano push volatile **nessuna** scrittura remota prima della conferma (se il coordinator partecipa al flusso).  
- **Service fake:** batch / **partial** → summary atteso mappato correttamente.  
- **UI Release:** sheet **senza** gergo tecnico vietato.  
- **UI Release:** **una sola** `.borderedProminent` per stato.  
- **Localizzazioni** IT/EN/ES/zh-Hans: nessuna promessa «tutto sincronizzato» in caso **partial**.  
- **Grep anti-scope:** nessun ProductPrice push, nessun outbox **drain**, nessun Timer/BGTask/Realtime/worker/polling, nessun Android, nessun SQL/backend nel perimetro iOS task.  
- **Regression:** flusso TASK-078 (pull apply) **invariato** nel comportamento approvato.

### 8-bis. Integrazione finale review — polish UI/UX e robustezza operativa

Questa integrazione chiude i punti ancora migliorabili del planning senza autorizzare execution. Le scelte sotto sono vincolanti per rendere la futura implementation più coerente con lo stile restante dell’app e più sicura su dati reali.

#### 8.1 Scelta copy finale consigliata

Tra **«Invia al cloud»** e **«Invia modifiche al cloud»**, la scelta preferita per la CTA primaria futura è:

> **Invia modifiche al cloud**

Motivo: comunica meglio che il flusso invia solo le modifiche locali candidate dal piano, non un upload cieco di tutto il database. Nei punti dove lo spazio è limitato, ad esempio menu o chip, è accettabile usare **«Invia al cloud»**.

#### 8.2 Release card: cosa mostrare e cosa no

La card in `OptionsView` deve restare coerente con lo stile attuale dell’app: compatta, leggibile, con una sola azione principale.

**Mostrare nella card:**

- stato sintetico;
- prossimo passo consigliato;
- CTA primaria;
- eventuale badge semplice: `Da inviare`, `Da aggiornare`, `Da correggere`, `Riprova`.

**Non mostrare nella card:**

- liste prodotto;
- dettagli batch;
- errori tecnici;
- termini interni;
- conteggi troppo granulari.

I dettagli vanno nella sheet **Rivedi**, con gerarchia visiva pulita.

#### 8.3 Sheet Rivedi: struttura UI consigliata

La futura sheet deve usare una struttura stabile:

1. **Summary card** in alto: frase breve + conteggi principali.
2. **Sezione direzione dati**: `Da questo dispositivo al cloud`.
3. **Sezione modifiche**: conteggi di create/update/link se disponibili.
4. **Sezione Attenzione**: warning non bloccanti.
5. **Sezione Da correggere**: blockers con messaggi action-oriented.
6. **Footer**: CTA primaria + Annulla.

La CTA deve restare nello stesso punto visivo tra preview, conferma, invio e summary. Questo riduce errori su iPhone e mantiene coerenza con le sheet già usate nei task precedenti.

#### 8.4 Reentrancy e doppio tap

TASK-079 deve pianificare un blocco esplicito contro azioni concorrenti:

- mentre il push è in corso, la CTA primaria è disabilitata o mostra progress;
- non si può avviare un secondo push;
- non si può confermare un piano stale;
- non si può cambiare account/sessione e continuare a usare lo stesso piano;
- se la sheet viene chiusa durante uno stato non terminale, il planning deve preferire annullamento sicuro oppure disabilitare la dismiss interattiva, secondo ciò che risulta più stabile in SwiftUI.

In execution, scegliere la soluzione più semplice e testabile: stato booleano/enum nel ViewModel prima di introdurre un orchestratore nuovo.

#### 8.5 Invalidazione push plan volatile

Il piano push in memoria non deve sopravvivere a cambiamenti che lo rendono potenzialmente sbagliato. Deve essere invalidato almeno in questi casi:

- nuovo **Controlla cloud**;
- apply locale TASK-078 completato;
- modifica locale rilevante su Product/Supplier/Category;
- cambio login, logout o sessione scaduta;
- cambio `ownerUserID`;
- fallimento terminale;
- successo terminale;
- cancel esplicito;
- app lifecycle se il ViewModel perde contesto.

Se l’invalidation non è implementabile in modo affidabile nel primo slice, il push deve richiedere un nuovo preflight immediatamente prima della conferma.

#### 8.6 Auth/session e stato rete

Prima di ogni write remota, il flusso deve ricontrollare auth/sessione in modo leggero. Se la sessione non è valida, fallire **prima** di scrivere remoto.

Copy consigliato:

- `Accedi per inviare modifiche al cloud.`
- `Connessione non disponibile. Riprova quando sei online.`
- `Non sono riuscito a completare l’invio. Nessuna modifica locale è stata persa.`

Non usare messaggi come `ownerUserID missing`, `RLS failed`, `JWT expired` o nomi interni nella UI Release.

#### 8.7 Performance su dataset grande

La futura implementation deve evitare una sheet pesante. Per cataloghi grandi:

- mostrare conteggi aggregati;
- mostrare al massimo pochi esempi se il modello li fornisce già;
- non introdurre ricerca/lista completa nella preview;
- non calcolare diff costosi più volte nello stesso ciclo UI;
- usare progress indeterminato se il progresso batch reale non è disponibile;
- evitare aggiornamenti UI troppo frequenti per ogni riga/batch.

Se serve una preview dettagliata completa, aprire un task successivo dedicato. TASK-079 resta sul push guidato, non su un diff browser.

#### 8.8 Decisione architetturale preferita

Se durante execution esiste una scelta tra:

- estendere leggermente `SupabaseManualSyncViewModel` + adapter/factory esistenti;
- creare un nuovo coordinator/facade pubblico;

preferire la prima opzione, finché resta leggibile e testabile. La motivazione è ridurre churn architetturale e mantenere simmetria con TASK-078. Un nuovo componente è accettabile solo se evita duplicazione reale o isolamento test nettamente migliore.

#### 8.9 Handoff per futura execution

Prima di passare a Codex/execution, il prompt successivo deve scegliere **una sola micro-slice** e indicare:

- file Swift esatti da toccare;
- test esatti da aggiungere/aggiornare;
- copy/localizzazioni necessarie;
- stato ViewModel da introdurre;
- come invalidare staging;
- check anti-scope;
- conferma che ProductPrice, outbox drain e conflitti avanzati restano fuori.

Senza questo handoff mirato, TASK-079 resta in planning.

#### 8.10 Edge case operativi da bloccare prima dell’execution

Prima di autorizzare codice Swift, il planning deve essere considerato incompleto se non sono coperti questi edge case:

- **zero-change:** nessuna modifica locale da inviare;
- **all-blocked:** tutti i candidati sono bloccati dal preflight;
- **partial success:** alcuni elementi inviati, altri no;
- **baseline refresh failed:** write remota riuscita ma read-back/baseline locale non aggiornata;
- **stale plan:** dati locali, sessione o baseline cambiano dopo la creazione del push plan;
- **network/auth pre-write failure:** errore prima della prima write;
- **network/auth mid-write failure:** errore durante batch successivi;
- **double tap / reentrancy:** due invii concorrenti;
- **dismiss durante invio:** sheet chiusa mentre il task non è terminale.

Questi casi non richiedono tutti una UI complessa nel primo slice, ma devono avere uno stato ViewModel e un copy minimo definiti prima dell’execution.

#### 8.11 Stato ViewModel consigliato

Per ridurre ambiguità in execution, preferire un enum di stato unico invece di molti booleani scollegati. Nomi indicativi, da adattare al codice reale:

- `idle`
- `checking`
- `reviewReady`
- `needsLocalApplyFirst`
- `preparingPushPlan`
- `readyToSend`
- `confirmingSend`
- `sending`
- `sendSucceeded`
- `sendPartiallySucceeded`
- `sendBlocked`
- `sendFailed`
- `stalePlan`

Il booleano `isSending` può esistere come derivato/comodità, ma non deve diventare l’unica fonte di verità se gli stati crescono.

#### 8.12 Consolidamento finale del copy

Per evitare incoerenze tra sezioni del plan, la regola finale è:

- CTA primaria standard: **Invia modifiche al cloud**;
- CTA compatta ammessa: **Invia al cloud**;
- Pull apply locale: **Aggiorna questo dispositivo**;
- Azione read-only: **Controlla cloud**;
- Stato senza modifiche: **Nessuna modifica locale da inviare**;
- Stato bloccato: **Da correggere**;
- Retry: **Riprova**.
- Successo prudente post-baseline-failed: **Modifiche inviate. Ricontrolla il cloud per aggiornare lo stato locale**.

Qualsiasi execution futura deve aggiornare le stringhe in modo coerente con questa matrice e non reintrodurre alternative non decise.

#### 8.13 Polish visuale finale per Release

La futura UI deve sembrare una continuazione naturale della card Supabase in `OptionsView`, non una schermata tecnica separata.

Regole visuali consigliate:

- usare una **summary card** in alto con titolo breve e sottotitolo esplicativo;
- usare `Label`/SF Symbols in righe compatte, non grandi banner tecnici;
- mantenere spacing coerente con le card esistenti dell’app;
- usare `Section`/`DisclosureGroup` solo se già coerente con il codice attuale;
- preferire conteggi aggregati e massimo pochi esempi;
- tenere il footer della sheet semplice: CTA primaria + Annulla/Chiudi;
- non mostrare JSON, ID remoti, ownerUserID, nome tabella o nomi enum Swift.

Gerarchia consigliata nella sheet:

1. **Titolo:** `Invia modifiche al cloud`
2. **Sottotitolo:** frase breve su cosa succederà.
3. **Summary:** numero elementi pronti / da correggere / già aggiornati.
4. **Dettagli compatti:** sezioni `Pronto da inviare`, `Attenzione`, `Da correggere`.
5. **Footer:** CTA primaria coerente con lo stato.

#### 8.14 Prima micro-slice consigliata dopo review

Quando verrà autorizzata execution, la prima micro-slice consigliata è **S79-b — Preflight push read-only**, non la UI completa.

Motivo:

- conferma che i servizi push esistenti funzionano nel contesto Release;
- permette di testare zero-change/all-blocked/stale senza scrivere remoto;
- evita di costruire UI sopra stati non verificati;
- mantiene il rischio basso e non apre TASK-080.

S79-b deve produrre solo stato leggibile e testabile. La CTA mutativa e la write remota restano per slice successivi.

---

## 8. Decisioni tecniche (D79-xx) — bozza planning

| ID | Decisione | Nota |
|----|-----------|------|
| **D79-01 Batching** | Riusare `maxBatchSize` di `SupabaseManualPushService` (default **50**); nessun batching UX visibile. | |
| **D79-02 Partial success** | Mappare `SupabaseManualPushTerminalStatus.partial` e `.completedBaselineRefreshFailed` su copy prudente; non dichiarare «tutto inviato» se partial. | |
| **D79-03 Retry manuale** | Solo **manuale** (`Riprova` / nuovo preflight dopo recovery); nessun retry automatico in background. | |
| **D79-04 Cancellazione** | Valutare `Task.checkCancellation()` su operazioni lunghe; allineamento ai pattern TASK-075/078; cancellazione non deve lasciare promessa di completamento. | |
| **D79-05 Conflitti** | Nessuna risoluzione silenziosa oltre i blockers del preflight; estensioni **TASK-082**. | |
| **D79-06 ProductPrice** | Escluso; **TASK-080**. | |
| **D79-07 Outbox drain** | Non richiesto per invio catalogo; drain controllato **TASK-081**. Eventuale **solo enqueue** post-push: decisione in execution/review se nel perimetro sicuro. | |
| **D79-08 Idempotenza** | Riallinearsi al comportamento gia’ testato in `SupabaseManualPushServiceTests` (retry/re-read); evitare doppie creazioni incoerenti. | |

**Allineamento:** decisioni **D79-UX** e **D79-EFF** nella sezione **Review planning**, §4.


---

## 9. Micro-slice future di execution (S79-a…S79-g)

Definizione aggiornata nella sezione **Review planning**, **§6** (slice piccole e testabili). Riassunto:

| Slice | Contenuto |
|-------|-----------|
| **S79-a** | Planning review finale |
| **S79-b** | Preflight push read-only |
| **S79-c** | Push plan volatile |
| **S79-d** | Review sheet Release |
| **S79-e** | Push manuale confermato |
| **S79-f** | Summary e retry manuale |
| **S79-g** | Baseline refresh post-write controllato |

Se la planning review indica che il coordinator deve restare l’unico orchestratore, **S79-c…e** possono ripacchettarsi senza cambiare l’obiettivo di sicurezza.

---

## 10. Test matrix (pianificata + aggiuntiva)

| Area | Tipo | Note |
|------|------|------|
| ViewModel Release | **Unit / XCTest** | Stati pre-push, post-push, partial, blocked; fake `SupabaseManualPushRemoteGateway`. |
| Coordinator | **Fake / stub** | Se il coordinator viene toccato: simulare fasi senza rete. |
| `SupabaseManualPushService` | **Service fake** | Estendere pattern `SupabaseManualPushServiceTests` / `FakeManualPushRemoteGateway`. |
| UI Release | **XCTest mirati / snapshot leggeri** | Sheet + CTA; niente stringhe jargon vietate. |
| Localizzazioni | **`plutil` / chiavi** | Chiavi user-facing; nessuna promessa «tutto sincronizzato» in caso **partial** (IT/EN/ES/zh-Hans). |
| Grep anti-scope | **Statico** | No ProductPrice push, no outbox **drain**, no `BGTask`/`Timer`/Realtime/worker/polling, no Android/SQL/backend nel perimetro task iOS. |
| Outbox | **Opzionale** | Se enqueue aggiunto: tests tipo `SyncEventOutboxEnqueueServiceTests`. |
| ViewModel (CTA) | **Unit** | Transizioni **Controlla cloud** / **Aggiorna questo dispositivo** / **Invia modifiche al cloud** / **Riprova**. |
| ViewModel (ordine) | **Unit** | Remote+local → ordine consigliato **non** sync unica ambigua (prima pull apply, poi push). |
| Coordinator fake | **Test** | Piano push volatile: nessuna write remota prima della conferma (se applicabile). |
| Service fake | **Test** | Batch / partial → summary mappato correttamente. |
| UI Release | **Statico / UI test** | Una sola `.borderedProminent` per stato; sheet senza gergo tecnico. |
| Regression | **XCTest** | TASK-078 pull apply **invariato**. |
| Edge case zero-change/all-blocked | **Unit** | Nessuna write remota se non ci sono candidati o se tutti i candidati sono bloccati. |
| Stale push plan | **Unit** | Modifica locale/sessione/baseline dopo preflight invalida il piano e richiede nuovo controllo. |
| Reentrancy | **Unit / UI** | Doppio tap sulla CTA non avvia due push. |
| Baseline refresh failed | **Service/ViewModel fake** | Write riuscita + baseline fallita produce summary prudente, senza retry write automatico. |
| Dismiss durante invio | **UI / state test** | Sheet non perde stato non terminale e non mostra successo/fallimento falso. |
| Mapping risultati push | **Unit** | `completed`, `completedBaselineRefreshFailed`, `partial`, `blockedBeforeWrite`, `failedBeforeWrite` mappati a copy e CTA corretti. |
| Polish copy statico | **Statico / grep** | Nessun copy Release contiene `RPC`, `outbox`, `baseline`, `payload`, `ownerUserID`, nomi tabella o enum Swift. |

**Dettaglio** casi ViewModel/UI/grep aggiuntivi: **Review planning**, **§7**.

---

## 11. Rischi

| Rischio | Mitigazione (planning) |
|---------|-------------------------|
| Duplicati barcode / nomi fornitore-categoria | Preflight gia’ modella ambiguita’; UX deve spiegare blocco in linguaggio naturale; vincoli DB unici parziali. |
| Supplier/category **manca** remoto ma prodotto lo referenzia | Ordine supplier → category → product nel servizio; blockers nel piano se dipendenze non risolvibili. |
| Mismatch ID locale/remoto | Link/create/update distinti nel piano; refresh baseline dopo successo. |
| `updated_at` / conflitti | Segnalazione onesta; policy completa **TASK-082**. |
| Partial batch | Summary che distingue «alcune modifiche inviate» vs «operazione interrotta». |
| Retry idempotente | Ripresa manuale solo dopo nuovo preflight / piano coerente con stato SwiftData. |
| Summary che promette troppo | Vietato «tutto sincronizzato» generico; coerenza TASK-074. |
| Piano push stale | Fingerprint/token dello snapshot locale + invalidazione su cambi SwiftData/sessione/baseline. |
| Doppio invio | Reentrancy guard e CTA disabilitata durante `sending`. |
| Nessuna modifica / tutti bloccati | Preflight leggero e CTA mutativa disabilitata prima di qualsiasi write. |
| Baseline refresh fallita dopo write | Summary prudente; nuovo **Controlla cloud** invece di ripetere write automaticamente. |
| Chiusura sheet durante invio | Stato terminale mantenuto nel ViewModel; dismiss controllata se necessario. |

---

## 12. Definition of Ready (per futura EXECUTION)

La futura **EXECUTION** e’ pronta solo se:

- [ ] I servizi iOS di **push catalogo** sono identificati con **nomi reali** nel codice (es. `SupabaseManualPushService`, `SupabaseManualPushPreflightService`, gateway ecc.).
- [ ] Il **preflight** e’ **fakeable** e **testabile** senza rete obbligatoria.
- [ ] Lo **schema Supabase** locale (clone migrazioni) **conferma** colonne e vincoli attesi per `inventory_*`.
- [ ] **Supplier/category mancanti:** policy chiara (crea se supportato dal piano/servizio; altrimenti blocca righe / «Da correggere»).
- [ ] **Barcode duplicati:** policy chiara (blocco + «Da correggere»).
- [ ] **ProductPrice** resta **fuori** (**TASK-080**).
- [ ] **Outbox drain** resta **fuori** (**TASK-081** / non implicito in TASK-079).
- [ ] La **UI** futura ha **copy deciso** e non tecnico: CTA primaria **Invia modifiche al cloud**, fallback compatto **Invia al cloud**, divieti §7 e Review §2.
- [ ] **Batch** / **partial** / **retry** sono **definiti** prima di modificare Swift.
- [ ] Review completata su questo planning (handoff §14).
- [ ] Scelta confermata: orchestrazione principale **ViewModel** vs **Coordinator** (linea guida TASK-078).
- [ ] Invalidation policy del push plan volatile definita e testabile.
- [ ] Reentrancy guard definito (`isSending` / enum equivalente) prima della write remota.
- [ ] Auth/session pre-write check definito con copy user-facing.
- [ ] CTA finale scelta: preferenza **Invia modifiche al cloud**; fallback compatto **Invia al cloud** solo dove serve spazio.
- [ ] La Release card resta compatta: dettagli solo nella sheet **Rivedi**.
- [ ] Performance dataset grande: niente lista completa / diff browser in TASK-079.
- [ ] Edge case zero-change, all-blocked, partial, baseline refresh failed e stale plan hanno stato + copy definiti.
- [ ] Token/fingerprint di validità del push plan definito oppure fallback obbligatorio a nuovo preflight prima della conferma.
- [ ] Dismiss/interazione durante `sending` definita: disable dismiss o mantenimento stato terminale sicuro.
- [ ] Matrice copy consolidata rispettata: **Controlla cloud**, **Aggiorna questo dispositivo**, **Invia modifiche al cloud**, **Da correggere**, **Riprova**.
- [ ] Mapping risultati push → UX Release definito per tutti gli esiti terminali del servizio.
- [ ] Prima execution proposta limitata a **S79-b — Preflight push read-only**, salvo override esplicito dell’utente.
- [ ] Polish visuale Release definito: summary card, sezioni compatte, no dettagli tecnici nella UI.

---

## 13. Definition of Done (planning)

Il planning puo’ andare in **review** solo se contiene:

- [x] **Flusso UX finale** scelto (step singolo; ordine pull apply → push se remote+local; sezione **Review planning**).
- [x] Decisioni **D79-xx**, **D79-UX**, **D79-EFF**.
- [x] Micro-slice **S79-a…S79-g**.
- [x] **Test matrix** aggiornata (§10 + Review §7).
- [x] Review finale UX/efficienza integrata: copy CTA scelto, card Release compatta, sheet structure, invalidazione staging, auth/session, reentrancy e performance dataset grande.
- [x] Review finale ripulita: copy consolidato, numerazione `8-bis`, edge case operativi, stato ViewModel consigliato e test extra aggiunti.
- [x] Review finale extra integrata: mapping risultati push→UX, polish visuale Release, prima micro-slice consigliata S79-b e copy residuo unificato.
- [x] **Rischi** con mitigazioni (§11).
- [x] Conferma esplicita:  
  - **TASK-079** resta **ACTIVE / PLANNING**  
  - **TASK-079 NON DONE**  
  - **NON READY FOR EXECUTION**  
  - **TASK-080 non aperto**

Altri elementi gia’ soddisfatti:

- [x] File task con inventario repo-grounded, gap analysis, schema Supabase (lettura clone).
- [x] Nessuna modifica Swift, SQL, Localizable, `project.pbxproj`, backend, Android in questo turno planning-only.

---

## 14. Handoff

| Voce | Valore |
|------|--------|
| **Stato task** | **ACTIVE / PLANNING** |
| **Esito** | **READY FOR PLANNING REVIEW — final refined plus** |
| **Execution** | **NON READY FOR EXECUTION** |
| **Prossima fase** | Planning review (utente / Claude) |
| **Prossimo agente** | Claude / Reviewer (poi, se approvato, Codex su override esplicito) |
| **TASK-080** | **Non aperto** |
| **TASK-079 DONE** | **No — TASK-079 NON DONE** |

**Conferme obbligatorie:** **TASK-079** resta **ACTIVE / PLANNING**; **TASK-079 NON DONE**; **NON READY FOR EXECUTION**; **TASK-080 non aperto**. Questa integrazione è solo planning markdown e non autorizza alcuna execution Swift/Supabase.

## 15. Check finali planning-only

Prima di passare a qualunque prompt operativo, il reviewer deve verificare:

- [ ] Il documento resta solo planning e non contiene istruzioni di write remota immediata.
- [ ] La prima slice esecutiva proposta è **S79-b — Preflight push read-only**, salvo override esplicito.
- [ ] Il mapping risultati push→UX è in **§4-bis**, prima dei casi di scelta e della test matrix.
- [ ] Il copy Release resta consolidato: **Controlla cloud**, **Aggiorna questo dispositivo**, **Invia modifiche al cloud**, **Da correggere**, **Riprova**.
- [ ] Nessun riferimento UI Release usa termini tecnici vietati: `RPC`, `outbox`, `baseline`, `payload`, `ownerUserID`, nomi tabella o enum Swift.
- [ ] **TASK-079** resta **ACTIVE / PLANNING**, **NON DONE**, **NON READY FOR EXECUTION**.
- [ ] **TASK-080** resta non aperto.

---

## Planning (Claude)

### Obiettivo tecnico sintetizzato

Portare il **push catalogo** da superficie **DEBUG** (`SupabasePushPreflightViewModel` + sezione Opzioni `#if DEBUG`) a un percorso **Release** coerente con TASK-078: conferma esplicita, servizi esistenti, summary prudente, refresh baseline post-successo gia’ previsto dal codice push.

### Analisi

Il lavoro pesante lato rete e SwiftData **durante** il push (incluso aggiornamento `remoteID` locali dopo create) e’ gia’ in `SupabaseManualPushService`. Manca principalmente l’**incollaggio** alla card Release, lo **staging** del piano dopo **Rivedi**, il mapping risultati push→UX e il **divieto di jargon** in UI.

### Approccio proposto (minimo)

1. Riusare preflight + `execute` senza duplicare logica RPC/tabelle.  
2. Simmetria TASK-078: stato volatile in `SupabaseManualSyncViewModel` (o componente dedicato interno), nessuna promessa persistente.  
3. Valutare se il coordinator debba solo restare **dry-run** per «Controlla cloud» e lasciare il push come **azione secondaria** post-review (riduce rischio di abilitare `guidedManual`).

### File probabilmente coinvolti (solo elenco futuro, non modifica ora)

- `SupabaseManualSyncViewModel.swift`, `OptionsView.swift` (sheet/card), `SupabaseManualSyncReleaseFactory.swift`, eventuali modelli presentation review; test in `iOSMerchandiseControlTests/`.

### Rischi identificati

Vedi §11; in piu’ **complessita’ UX** se pull staging e push staging coesistono nella stessa sessione (regole di invalidazione chiare).

### Handoff → Planning review

- **Prossima fase:** planning review finale. Se approvato con override esplicito, la prima execution consigliata resta **S79-b — Preflight push read-only**; enqueue/outbox solo se esplicitamente nel perimetro, senza drain Release.  
- **Prossimo agente:** Claude / Reviewer o utente.  
- **Azione consigliata:** approvare o correggere il planning; non avviare Swift execution finché non esiste un prompt separato su una sola micro-slice.  
- **Stato:** **TASK-079 ACTIVE / PLANNING**, **NON DONE**, **NON READY FOR EXECUTION**; **TASK-080 non aperto**.
- **Review finale integrata:** CTA preferita **Invia modifiche al cloud**, card Release compatta, sheet Rivedi più strutturata, invalidazione push plan volatile, reentrancy guard, auth/session pre-write check e performance dataset grande pianificati; nessuna execution autorizzata.
- **Review finale extra integrata:** copy consolidato definitivo, sezione numerazione `8-bis`, edge case zero-change/all-blocked/partial/stale/baseline-failed, fingerprint push plan, stato ViewModel consigliato e test reentrancy/dismiss pianificati; resta planning-only.
- **Ultima review extra integrata:** copy residuo unificato, mapping risultati push→UX (§4-bis), polish visuale Release e prima micro-slice consigliata **S79-b preflight read-only**; nessuna execution autorizzata.

---

## Execution (Codex)

### Override operativo

L'execution e' stata avviata su override esplicito dell'utente nonostante lo stato precedente del file fosse **ACTIVE / PLANNING** e **NON READY FOR EXECUTION**. Impatto tracking: il task resta **ACTIVE**, passa a **REVIEW** per controllo Claude, e **non** viene marcato **DONE** da Codex.

### Obiettivo compreso

Portare in Release un flusso guidato, manuale e confermato per inviare il catalogo locale verso Supabase, riusando `SupabaseManualPushPreflightService` e `SupabaseManualPushService`, mantenendo la card Release compatta e mettendo dettagli/summary nella sheet **Rivedi**.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-079-supabase-guided-catalog-push-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift`
- Test manual sync, preflight, push e Release UI esistenti.

### Piano minimo seguito

1. Estendere il ViewModel Release con stato push volatile, senza nuovo coordinator pubblico.
2. Collegare in factory un adapter Release che costruisce il piano con preflight read-only e usa il servizio push esistente solo dopo conferma.
3. Aggiornare la card/sheet Release con una sola CTA primaria per stato e copy user-facing senza jargon.
4. Aggiungere test mirati per preflight, staging, stale plan, conferma, reentrancy, mapping risultati, priorita' pull apply e copy UI.

### Micro-slice completate

- **S79-b — Preflight push read-only:** completata. Il controllo usa `SupabaseManualPushPreflightService` tramite adapter Release; nessuna chiamata a `execute` durante preflight.
- **S79-c — Push plan volatile / staging:** completata. Piano in memoria nel ViewModel, fingerprint ricontrollato prima della write, invalidazione su nuovo controllo, apply locale riuscito, cambio account/sessione, cancel, success/failure terminale.
- **S79-d — Review sheet Release:** completata. Card compatta; sheet **Rivedi** con sezioni **Pronto da inviare**, **Attenzione**, **Da correggere**, **Summary finale**; dettagli limitati a conteggi aggregati.
- **S79-e — Push manuale confermato:** completata. `SupabaseManualPushService.execute` chiamato solo dopo conferma esplicita; guardia reentrancy/doppio tap; nuovo preflight immediatamente prima della write.
- **S79-f — Summary e retry manuale:** completata. Mapping user-facing per `completed`, `completedBaselineRefreshFailed`, `partial`, `blockedBeforeWrite`, `failedBeforeWrite`, stale e zero-change; retry passa da nuovo **Controlla cloud**.
- **S79-g — Baseline refresh post-write controllato:** completata usando solo il comportamento esistente del servizio push; fallimento refresh post-write mostrato come successo prudente con invito a ricontrollare.

### Modifiche fatte

- `SupabaseManualSyncViewModel.swift`: stati catalog push, summary user-facing, review sheet push, staging volatile, invalidazione, stale check, reentrancy guard, mapping risultati push, priorita' **Aggiorna questo dispositivo** quando coesistono remote+local.
- `SupabaseManualSyncReleaseFactory.swift`: wiring opzionale `SupabaseManualPushService` e adapter privato Release per baseline reader + snapshot SwiftData + preflight + execute.
- `OptionsView.swift`: passaggio `manualPushService` alla Release card, conferma separata per invio al cloud, task send dedicato, dismiss disabilitato durante apply/send.
- `Localizable.strings` IT/EN/ES/zh-Hans: copy Release push necessario.
- `SupabaseManualSyncViewModelTests.swift`: fake provider e test TASK-079 per zero-change, candidati validi, blockers, auth failure, stale plan, result mapping, double send, priorita' pull apply.
- `SupabaseManualSyncReleaseUITests.swift`: localizzazioni/copy/static source aggiornati per TASK-079.

### Check eseguiti

- ✅ **Build compila (Xcode / BuildProject):** `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS. Warning residui preesistenti/out-of-scope in `SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`, AppIntents metadata.
- ✅ **XCTest ViewModel/UI Release:** `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests` PASS: 66 test, 0 failure.
- ✅ **XCTest preflight/push service:** `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualPushPreflightTests -only-testing:iOSMerchandiseControlTests/SupabaseManualPushServiceTests` PASS: 42 test, 0 failure.
- ✅ **Localizzazioni:** `plutil -lint` su IT/EN/ES/zh-Hans PASS.
- ✅ **Nessun warning nuovo introdotto:** verificabile sui file modificati; warning Xcode rilevati sono preesistenti/out-of-scope.
- ✅ **Modifiche coerenti con il planning:** nessun ProductPrice implementato, nessun drain outbox, nessuna sync automatica, nessun backend/SQL/Android.
- ✅ **Criteri di accettazione verificati:** CA funzionali coperti da test statici/unitari e build; nessun test Simulator manuale richiesto dal task.

### Cosa non e' stato implementato

- ProductPrice / storico prezzi remoto.
- TASK-080.
- Android, backend, SQL migrations, `db push`.
- Drain outbox, sync automatica, Timer/BGTask/Realtime/worker/polling.
- Rollback automatico post-write: recovery resta summary, nuovo preflight, retry manuale.

### Rischi rimasti

- Il push Release e' verificato con test/fake e build locale; non e' stato eseguito smoke live contro Supabase reale.
- Warning Swift 6 preesistenti in ProductPrice/outbox restano fuori perimetro TASK-079.
- Follow-up candidate: eventuale polish visuale/manuale su dispositivi reali se il reviewer vuole evidenza Simulator specifica.

## Handoff post-execution (Codex)

| Voce | Valore |
|------|--------|
| **Stato task** | **ACTIVE** |
| **Fase attuale** | **REVIEW** |
| **Esito Codex** | **EXECUTION completata / READY FOR REVIEW** |
| **Prossimo agente** | **Claude / Reviewer** |
| **TASK-079 DONE** | **No — Codex non marca DONE; propone chiusura solo dopo review/utente** |
| **TASK-080** | **Non aperto** |

**Conferme:** nessun ProductPrice; nessun TASK-080 aperto; nessun Android/backend/SQL; nessun outbox drain; nessuna sync automatica; UI Release senza jargon tecnico vietato nei valori manual sync.

## Review Claude

### Esito review

**FIXED / APPROVED — TASK-079 DONE / Chiusura.**

Review completa eseguita su override utente dopo execution Codex, con controllo del diff, tracking, Swift coinvolti, test e localizzazioni. L'implementazione e' coerente con il plan TASK-079: flusso Release **Controlla cloud → Rivedi → Conferma → Invia modifiche al cloud → Summary**, card compatta, dettagli nella sheet, preflight read-only, piano volatile, write solo dopo conferma, summary stabile e retry manuale tramite nuovo controllo.

### Problemi trovati

- **Auth/session race pre-write:** dopo il secondo preflight anti-stale, la sessione poteva cambiare prima di `SupabaseManualPushService.execute`. Il rischio era piccolo ma reale rispetto al contratto TASK-079: nessuna write se auth/session/owner non sono ancora validi immediatamente prima della scrittura.
- **Polish copy IT:** una stringa Release usava "Summary finale"; sostituita con "Riepilogo finale".
- **Copertura anti-jargon:** estesa la lista testata per includere anche `baseline`, `ownerUserID` / `owner_user_id`, `JWT`, `RLS`.

### Fix applicati

- `SupabaseManualSyncViewModel.swift`: aggiunto recheck di `authPresentationContext.isSignedIn`, `currentCatalogPushOwnerID` e `currentPlan.ownerUserID` subito prima di `execute`; in caso di mismatch il flusso fallisce prima della write con copy user-facing.
- `SupabaseManualSyncViewModelTests.swift`: aggiunto `testTask079SessionChangeDuringPreWriteRecheckDoesNotExecute`, che simula cambio sessione tra re-preflight e write e verifica `executeCallCount == 0`.
- `SupabaseManualSyncReleaseUITests.swift`: rafforzato il test copy Release no-jargon.
- `it.lproj/Localizable.strings`: copy finale piu' naturale.

### Check eseguiti

- ✅ **git diff --check:** PASS.
- ✅ **Build Release:** `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS. Warning residui preesistenti/out-of-scope in ProductPrice/outbox/AppIntents.
- ✅ **XCTest ViewModel/UI Release:** `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests` PASS.
- ✅ **XCTest preflight/push service:** `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualPushPreflightTests -only-testing:iOSMerchandiseControlTests/SupabaseManualPushServiceTests` PASS.
- ✅ **plutil localizzazioni:** IT/EN/ES/zh-Hans PASS.
- ✅ **Grep anti-scope su diff:** PASS, nessun ProductPrice/TASK-080/outbox drain/BGTask/Timer/Realtime/polling/Android/migration SQL introdotto nel perimetro TASK-079.
- ✅ **Grep anti-jargon UI Release/manualSync:** PASS, nessun `RPC`, `outbox`, `sync_events`, `baseline`, `payload`, `DTO`, `ownerUserID`, `JWT`, `RLS` nei valori Release manual sync.

### Conferme finali

- Nessun ProductPrice sync implementato.
- Nessun TASK-080 aperto.
- Nessun Android/backend/SQL/migration/db push.
- Nessun outbox drain.
- Nessuna sync automatica, Timer, BGTask, Realtime, worker o polling.
- UI Release senza jargon tecnico vietato.
- TASK-078 pull apply invariato: test TASK-078 nella suite ViewModel ancora PASS.
- Partial success resta partial, baseline refresh failed resta successo prudente e non ripete automaticamente la write.

### Motivazione chiusura

Le micro-slice S79-b…S79-g risultano implementate e verificate con fix mirato sul solo rischio reale emerso in review. Il flusso resta manuale, confermato, delta-aware, senza scope creep e senza aprire TASK-080. **TASK-079 e' chiuso DONE / Chiusura.**
