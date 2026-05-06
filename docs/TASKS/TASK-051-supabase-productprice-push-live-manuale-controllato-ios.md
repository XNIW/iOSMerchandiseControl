# TASK-051: Supabase ProductPrice — **push live manuale controllato iOS** (**no sync_events / no outbox**)

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-051
- **Titolo**: Supabase ProductPrice push live manuale controllato iOS — dry-run obbligatorio, read-back, idempotenza, zero extras
- **File task**: `docs/TASKS/TASK-051-supabase-productprice-push-live-manuale-controllato-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Codex / Reviewer+Fixer
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(REVIEW severa completata su override esplicito utente; esito APPROVED_FIXED_DIRECTLY / DONE dopo fix piccoli, build/test/check PASS. Smoke live reale resta follow-up manuale separato.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

## Dipendenze
- **Dipende da** *(tutti DONE / Chiusura — non riaprire)*:
  - **TASK-048** — preview read-only `inventory_product_prices`, ordinamento deterministico, XCTest.
  - **TASK-049** — pull → apply locale **insert-only**; normalizzazione chiavi/prezzi; **nessun** push in quel task.
  - **TASK-050** — preflight + **dry-run zero-write**; `SupabaseProductPricePushDryRunService`, summary tipizzato, dedupe remoto batch, UI DEBUG **solo anteprima**; **nessun** write remoto.
  - **TASK-038** — auth Supabase; gate account.
  - **TASK-043/TASK-044** — baseline catalogo valida; pattern push manuale catalogo *(solo riferimento architetturale; questo task tocca **solo** `inventory_product_prices`)*.
- **Sblocca** *(solo dopo DONE + conferma utente; non attivare qui)*:
  - Eventuali task futuri: `record_sync_event`, outbox/retry, realtime, sync automatico, tombstone outbound — **esplicitamente fuori da TASK-051**.

### Verifica repo GitHub *(planning 2026-05-06)*
- Remote: `origin` → `https://github.com/XNIW/iOSMerchandiseControl.git`.
- `git fetch origin main` eseguito: **`HEAD` locale = `origin/main` = `17315a7`** (*commit message: Task 50*).
- In **EXECUTION**: ripetere `fetch` e verificare allineamento branch prima di patch, salvo istruzione utente diversa.

---

## 1. Titolo

**TASK-051 — Supabase ProductPrice push live manuale controllato iOS**: primo push remoto **manuale**, **controllato** e **limitato** alla tabella **`inventory_product_prices`**, con **dry-run TASK-050 obbligatorio** prima di ogni scrittura, **read-back** post-insert e verifica **idempotenza / no-op** su dry-run successivo.

---

## 2. Stato / fase / responsabile

| Campo | Valore |
|-------|--------|
| Stato globale progetto *(MASTER-PLAN)* | **IDLE** |
| Stato task | **DONE** |
| Fase | **Chiusura** |
| Responsabile | **Codex / Reviewer+Fixer** |
| Nota | Review completata su conferma esplicita utente; smoke live reale resta follow-up manuale separato. |

---

## 3. Contesto iOS

- **Pipeline TASK-048 → 049 → 050** ha portato: lettura cloud storico, apply locale insert-only, dry-run push con gate baseline/auth/dedupe remoto **senza write**.
- **TASK-051** aggiunge unicamente: **insert remoto** delle righe classificate come **candidati pronti** dal dry-run **safe** corrente, poi **verifica remota** e **coerenza idempotente** *(nuovo dry-run: stesse righe ⇒ `alreadyPresentRemote` / ready=0)*.
- **Riferimento codice da rileggere integralmente in EXECUTION** *(nomi attesi dal repo post TASK-050; adattare se rename)*:
  - `SupabaseProductPricePushDryRunService.swift` — engine + orchestratore dry-run.
  - `SupabaseProductPricePreviewService.swift` / DTO `RemoteInventoryProductPriceRow` — shape lettura.
  - `SupabaseProductPriceApplyService.swift` — normalizzazione/chiavi coerenti con storico *(solo lettura concettuale; **nessun** apply in questo task)*.
  - `SupabaseInventoryService.swift` — client, select batch, estensioni fetch dry-run.
  - `Models.swift` — `Product`, `ProductPrice`, `Product.remoteID`.
  - `OptionsView.swift` — sezione DEBUG Supabase esistente (card dry-run TASK-050).
  - Test: `SupabaseProductPricePushDryRunServiceTests.swift`, `SupabaseProductPriceApplyServiceTests.swift`, `SupabaseProductPricePreviewServiceTests.swift`.
- **Clone allineato a GitHub** `main` al momento del planning *(vedi metadata)*.

---

## 4. Riferimento Android usato *(funzionale — nessuna modifica Android)*

- Android ha sync ProductPrice più maturo; **TASK-068** resta **PARTIAL** per scenari bulk / no-op live.
- **TASK-070 DONE**: retry/outbox **app-side** — **non** replicare su iOS in TASK-051.
- **TASK-071 DONE**: classificazione mismatch backend `record_sync_event` / `p_changed_count > 1000`; follow-up backend **TASK-072** separato.
- **Implicazione**: niente parità feature con Android; solo allineamento **semantico** dominio `inventory_product_prices` dove utile. **Nessun file Kotlin**, nessun merge Android.

---

## 5. Riferimento Supabase usato *(schema reale — lettura sola, nessuna migration in TASK-051)*

- **Fonte primaria** per DDL/policy: clone **`MerchandiseControlSupabase`** sul dev machine, cartella `supabase/migrations/`, in particolare:
  - `20260417200000_task016_inventory_product_prices.sql` — tabella **`inventory_product_prices`**, UNIQUE `(owner_user_id, product_id, type, effective_at)`, CHECK `type` ∈ `PURCHASE`/`RETAIL`, testi `effective_at` / `created_at`, FK `product_id` → `inventory_products`.
  - Migrazioni successive che toccano **DELETE**/**RLS** su prices (es. **038** revoca delete su authenticated) — **append-only** lato client; **nessuna delete remota** in TASK-051.
- **`docs/SUPABASE/TASK-033-schema-audit.md`** — riassunto e mapping; non sostituisce il DDL.
- **`record_sync_event` / `sync_events`**: presenti nel backend Android/Supabase master plan — **vietati** in TASK-051 (vedi §7).
- **Drift schema**: se in EXECUTION il DDL reale letto dal clone **diverge** da quanto assume il codice TASK-050/051 → **STOP**, restare in **PLANNING** o **BLOCKED** con nota nel file task *(no workaround silenziosi)*.

---

## 6. Obiettivo

Implementare e validare **il primo push live manuale controllato** da iOS verso **`inventory_product_prices`**, tale che:

1. **Ogni** operazione di scrittura sia preceduta da **dry-run TASK-050 safe** *(dedupe remoto completo, non `unsafePartialRemoteDedupe`, gate auth/baseline/candidati come già definiti in TASK-050)* e da uno **snapshot logico vincolante** *(vedi **D51-10**)* valido alla pressione del push.
2. **Solo** righe **candidati** con motivazione **`candidate`** e payload coerente vengono inviate *(insert)*.
3. Dopo insert: **read-back remoto** deterministico con **confronto exact-match** tra candidate e righe lette *(vedi **D51-05** / §9)* — **nessun successo parziale silenzioso**.
4. Dopo read-back positivo: aggiornare **solo stato volatile/UI** *(nessun outbox, nessuna persistenza “piano push”)* — **nessuna mutazione SwiftData** *(vedi §7 bis)*.
5. **Idempotenza**: rieseguire **dry-run** dopo push riuscito ⇒ per le stesse righe esito **no-op** *(es. conteggio `readyCandidates` 0, `alreadyPresentRemote` coerente)*.
6. **UI Avanzata / DEBUG** in `OptionsView` *(non presentata come sync “normale”)*: copy esplicito **push manuale storico prezzi**, badge, flow a step, conferma, stati push/read-back/idempotenza — **IT / EN / ES / zh-Hans**.

---

## 7. Non-obiettivi *(fuori perimetro assoluto)*

- **`record_sync_event`**, **`sync_events`**, qualsiasi RPC telemetry di sync.
- **Outbox**, retry persistente, **realtime**, **background sync**, **push automatico**.
- **`service_role`** o segreti nel client.
- **Migration SQL**, **RLS**, **RPC**, Edge Functions, modifiche Supabase workspace.
- **Delete** remota, **update** remota, tombstone outbound su prices.
- Modifica **Android**.
- Modifica **`Product.purchasePrice` / `Product.retailPrice`** (prezzi correnti).
- **Update / delete** di righe **`ProductPrice`** SwiftData esistenti; **nessun** apply pull→locale in questo task.
- **Sync all** generico catalogo; **nessun** riuso CTA “Sync” / “Upload all” / “Carica tutto” — copy solo esplicito **push manuale storico prezzi**.
- **Ottimizzatori bulk**, **lotti multipli automatici** senza decisione esplicita futura, **retry persistente**, **successo parziale accettato** come DONE.

### 7 bis. Post-success remoto — divieti mutazione locale

Dopo un push/read-back considerato **riuscito** ai fini CA *(solo in EXECUTION/review, quando applicabile)*:

- **Non** aggiornare `Product.purchasePrice` / `Product.retailPrice`.
- **Non** creare/aggiornare/eliminare righe **`ProductPrice`** SwiftData per “allineare” il cloud.
- **Non** marcare righe locali come *synced* / *pushed* *(nessun flag persistito su modello)*.
- **Non** salvare in **UserDefaults**, file o baseline il **piano push** o lo snapshot dry-run *(lo snapshot è solo guardia **in-memory** / ViewModel — vedi **D51-10**)*.
- Sono ammessi **soltanto** stati volatili UI / ViewModel *(messaggi di esito, chip read-back, hint “ricalcola anteprima”)*.

---

## 8. Decisioni tecniche *(planning — da confermare/rafforzare in EXECUTION con codice reale)*

| ID | Decisione | Motivazione |
|----|-----------|-------------|
| **D51-01** | **Dry-run è precondizione hard**: niente `insert` senza risultato dry-run **safe** **corrente** e **snapshot logico valido** *(**D51-10**)*. | Evita push obsoleto o con dedupe stale. |
| **D51-02** | **Insert-only** su `inventory_product_prices`: payload allineato a `ProductPricePushDryRunCandidatePayload` / colonne DDL; **no upsert** che mascheri conflitti; **no** conversione automatica conflitto UNIQUE → upsert. | Append-only coerente con policy delete revocata e TASK-049. |
| **D51-03** | **Chiave primaria `id` — condizionata al DDL reale** *(obbligo: leggere migration `inventory_product_prices` in EXECUTION)*: **(a)** Se `id` ha **default server-side** *(es. `gen_random_uuid()`)* → il client **non** invia `id`; usa **risposta insert** *(es. `returning` / payload PostgREST)* e/o **read-back per chiave logica** per ottenere `id` verificabili. **(b)** Se `id` è **obbligatorio senza default** in DDL → usare **UUID deterministico** da chiave logica **stabile** *(es. UUID v5 su namespace+tuple canonico — esecutore documenta scelta dopo lettura migration)*. **(c)** **Vietato** UUID casuale **non** derivato da chiave nota e **non** collegabile al read-back. **(d)** Se il DDL non è chiaro, ambiguo o in conflitto con il client → **STOP** in **PLANNING/BLOCKED** fino a chiarimento — **nessun** workaround. | Tracciabilità read-back e idempotenza; niente identità fantasma. |
| **D51-04** | **Batch atomico v1 (singola richiesta)**: **un solo** `insert` per run entro **max 100 righe** *(max **200** solo se documentato in Execution)*. **Nessun** secondo batch nello stesso task: multi-batch automatico = **task futuro**. Se PostgREST/DB restituisce **errore sul batch**, trattare l’intera operazione come **fallita** o **incerta (D51-14)** — **mai** “metà successo” multi-batch. Se `readyCandidates` **>** limite → fail-closed UX **troppi candidati**; **non** inviare subset. | No partial success v1; blast radius controllato. |
| **D51-05** | **Insert + read-back + exact-match**: `returning` se utile; poi read-back. Confronto candidate ↔ righe lette con **stessa pipeline di normalizzazione D51-13**. **Una** assenza o mismatch ⇒ **failure** (non DONE). Owner verificato **solo** via sessione/RLS (**D51-12**), mai bypass. | Esito binario; coerenza con TASK-049/050. |
| **D51-06** | **Conflitto UNIQUE / race remota**: se PostgREST/Postgres risponde con **unique violation** *(stessa chiave logica già presente — altro device/run)* — **nessun retry automatico**, **nessun upsert**. Mostrare **errore controllato** in UI; **invalidare** snapshot push; richiedere **«Calcola anteprima»**. Il dry-run **successivo** deve classificare quelle righe come **già presenti remote** dove applicabile. | Coerenza no-outbox; utente consapevole. |
| **D51-07** | Stato UI post-success: **solo** `@State` / ViewModel volatile; **nessun** file/UserDefaults per coda push / snapshot persistito. | Perimetro utente. |
| **D51-08** | **Mapping `Product.remoteID`**: stessi gate TASK-050; duplicati/ambiguità → **blocco** push. | Coerenza identità remota. |
| **D51-09** | Copia UI: **vietati** termini generici “Sincronizza”, “Carica tutto”, “Upload all”; usare **“Push manuale storico prezzi”** / equivalenti localizzati; verifica su **IT/EN/ES/zh-Hans**. | Anti-travaso UX verso sync globale. |
| **D51-10** | **Snapshot** *(RAM/VM, non outbox)*: invalidazione su cambio auth, baseline, prodotti/`ProductPrice` locali, conteggio candidate, chiavi `(remoteProductId, type, effectiveAtCanonico)`, **fingerprint** insieme candidate, dedupe completo, timestamp run. Dettaglio fingerprint: **§8.1**; se TASK-050 espone hash equivalente → **riuso**. | Anti-push stale. |
| **D51-11** | **Async / MainActor / concorrenza UI**: async/await + MainActor. **«Calcola anteprima»** e **«Esegui push manuale»** **non** in parallelo; durante dry-run / push / read-back disabilitare azioni che alterano snapshot o seconda rete. **Doppio tap** ⇒ una chiamata. `Task` cancellato ⇒ **non** success *(stato `cancelled` — **D51-15**)*. | Evita race client. |
| **D51-12** | **`owner_user_id` / RLS / sessione** *(leggere DDL/policy in EXECUTION)*: decidere se `owner_user_id` è nel body client, **default** DB, o imposto da RLS/trigger. Se nel payload → **solo** `session.user.id`. **Vietato** owner da UI/parametri liberi. Ownership non chiara → **STOP** **PLANNING/BLOCKED**. Read-back: solo sessione+RLS; **no** `service_role`. | Tenant-safe. |
| **D51-13** | **Normalizzazione condivisa TASK-049/050**: stesse regole servizi esistenti. **`type`**: **`PURCHASE`**/**`RETAIL`**. **`effectiveAt`**: come TASK-049/050 — niente format nuovi ad hoc. **`price`**: amount canonico deterministico. Drift → STOP. | Un solo percorso. |
| **D51-14** | **Verifica incerta**: insert possibile ma read-back fallisce → **non** success; **no** retry stesso push; stato **`verificationUnknown`**; **ricalcola anteprima**. **≠** DONE finché non risolto. | No falsi DONE. |
| **D51-15** | **Enum stato unico** *(VM — **§8.4** `ProductPriceManualPushState`)*: `idle`, `dryRunRunning`, `previewSafe`, `previewUnsafe`, `snapshotStale`, `overBatchLimit`, `pushReady`, `pushRunning`, `readBackRunning`, **`verifiedSuccess`** *(unico successo pieno)*, **`verificationUnknown`**, `failedConflict`, `failedValidation`, `failedNetwork`, `cancelled`. CTA ↔ stato: **§10**. | Testabilità. |
| **D51-16** | **View / VM / Service**: `OptionsView` solo UI + azioni; **zero** Supabase in View. VM: **D51-15**, snapshot, CTA. Servizi: networking; normalizzazione **solo** in servizi TASK-049/050 (**D51-13**). Patch minime; no mega-service inutile. | Separazione netta. |

### Nota su D51-03 vs TASK-050

Il dry-run TASK-050 usa identità deterministiche per linee di report; il **push live** deve allinearsi al **vincolo DDL** su `id` senza contraddire la migration. Eventuale divergenza va risolta in EXECUTION con nota nel file task prima del merge review.

### §8.1 Fingerprint snapshot *(integra **D51-10** / **D51-13**)*

- Calcolare l’hash sulle tuple candidate in **rappresentazione canonica ordinata stabilmente**: **(1)** `remoteProductId` → **(2)** `type` → **(3)** `effectiveAtCanonico` → **(4)** `priceCanonico` *(valori già normalizzati)*. **Non** includere nel fingerprint nome prodotto, barcode o altri dati business se **non** necessari al vincolo.
- Log/review consentiti: **conteggi**, stato **D51-15**, **durata**, batch size, **reason code**, **fingerprint abbreviato** (primi/ultimi caratteri).
- Se in EXECUTION il servizio dry-run TASK-050 espone già un **fingerprint funzionalmente equivalente** sulla stessa rappresentazione → **riusarlo**, non duplicare algoritmi.

### §8.2 Log privacy-safe *(debug / review)*

- **Ammesso**: conteggi, stato VM, durata, batch size, reason code, hash/fingerprint **breve**.
- **Evitare**: nomi prodotto, barcode completi, prezzi riga-per-riga, `owner_user_id` in chiaro intero.
- Diagnosi per riga: **indice** nella lista candidate o **hash parziale** — mai payload business completo.

### §8.3 Execution gate obbligatorio prima del codice

**Codex**: prima di **qualsiasi** patch Swift, verificare e **documentare** in **Execution** *(anche bozza)*:

| # | Verifica |
|---|----------|
| 1 | DDL reale di **`inventory_product_prices`** *(clone migrazioni / fonte §5)*. |
| 2 | Decisione **D51-03** su **`id`** (default server vs invio client vs UUID deterministico). |
| 3 | Decisione **D51-12** su **`owner_user_id`** / RLS / payload. |
| 4 | Allineamento **D51-13** su **`type`**, **`effectiveAt`**, **`price`** al codice TASK-049/050. |
| 5 | **Limite batch effettivo v1** (**D51-04** — valore numerico chiuso). |
| 6 | **Fingerprint/snapshot**: riuso da **TASK-050** se già equivalente (**§8.1** / **D51-10**) **oppure** nuova implementazione motivata. |

Se **uno** di questi punti resta **ambiguo**: **STOP** — **non** scrivere codice push/read-back; aggiornare il task come **BLOCKED** o restare in **PLANNING** con **motivo esplicito** nel file task.

### §8.4 Naming consigliati *(EXECUTION — non vincolanti; evitare doppioni TASK-050)*

| Ruolo | Nome preferito | Note |
|-------|----------------|------|
| Servizio push live *(insert + orchestrazione read-back)* | `SupabaseProductPriceManualPushService` | Patch piccole su `SupabaseInventoryService` se serve; **no** mega-service (**D51-16**). |
| Stato UI / VM (**D51-15**) | `ProductPriceManualPushState` | Enum / struct unico, non boolean sparsi. |
| VM / controller DEBUG | `ProductPriceManualPushDebugViewModel` | Se il progetto **non** usa VM dedicati in Options, usare un **controller** / `@Observable` coerente con lo stile esistente — stesso ruolo. |
| DTO payload insert | `ProductPriceManualPushPayload` | Se già coperto da `ProductPricePushDryRunCandidatePayload` o equivalente TASK-050 → **riuso** / typealias, non duplicare campi. |
| Esito run push | `ProductPriceManualPushResult` | |
| Esito verifica read-back | `ProductPriceManualPushVerificationResult` | |

**Regola:** esistono già tipi/nomi equivalenti in **TASK-050** → **continuità** e adattamento minimale; **`OptionsView`**: solo UI + intent; **zero** chiamate Supabase in View (**D51-16**).

---

## 9. Piano execution *(sintesi — vedi §8.3, §14)*

**Ordine obbligatorio:** documentare e chiudere **§8.3** (**E0** nel file **Execution**) **prima** di qualsiasi patch Swift. Se **uno** dei gate è **ambiguo**: **STOP**; segnare **BLOCKED** o tornare a **PLANNING** con motivo chiaro; **vietato** scrivere codice push/read-back prima di aver chiuso i gate.

- **Prima di codice:** gate **§8.3** / **E0**; nomi indicativi **§8.4**.
- **Flusso:** dry-run TASK-050 + snapshot **D51-10** (**§8.1**) → **`insert` atomico D51-04** → read-back **D51-05** / **D51-13** → stati **D51-15**, UI **§10**, errori **§10**.
- **Qualità:** XCTest **§11** *(ordine gruppi A→B→C)*; checklist **§12**; review **§16**.

**STOP / non-DONE:** vedi §8; **D51-14** aperto; gate **§8.3** non soddisfatto.

---

## 10. UI/UX DEBUG *(OptionsView — Avanzata / DEBUG)*

### Scelta UX preferita *(definitiva — planning)*

- In **`OptionsView`**, una sezione con **header localizzato**: **«Avanzata»** / **«Advanced»** / **«Avanzado»** / **「高级」** *(come le altre stringhe tab Opzioni)*.
- Se coerente col codice attuale, racchiudere il blocco in **`DisclosureGroup`** così il push manuale **non** appare come azione principale dell’app.
- **Dentro** la sezione: titolo visibile **«Push manuale storico prezzi»** *(e equivalenti EN/ES/zh-Hans nei `Localizable.strings`)*.
- **Badge** piccoli **«Manuale»** e **«DEBUG»** accanto al titolo o in header secondario.
- **Bottone primario** *(`.buttonStyle` prominente / filled dove usato nel file)*: **«Calcola anteprima»**.
- **Bottone secondario** *(es. bordered / meno enfasi)*: **«Esegui push manuale»**.
- **`confirmationDialog`** **obbligatorio** prima del push (conteggi candidati + promemoria solo storico prezzi).
- **`ProgressView`** durante `dryRunRunning` / `pushRunning` / `readBackRunning`.
- **Footer** della sezione **sempre visibile** (non solo post-azione), testo esplicativo; **base IT:** *«Scrive solo lo storico prezzi su Supabase. Non sincronizza il catalogo né l'intero database.»* — tradurre in EN/ES/zh-Hans allineato al tono **§6**.
- In dubbio tra compatto e esplicito: **più esplicito**, **nativo iOS** (SwiftUI standard); **no** pattern stile Android; **no** “card” celebrativa post-success; successo sobrio: **«Push verificato»** (variante lunga ammessa, v. tabella sotto).
- **Divieti copy:** Sync / Upload all / Carica tutto (**D51-09**).

### Stato unico (D51-15) → abilitazione CTA *(indicativa)*

| Stato | «Calcola anteprima» | «Esegui push manuale» |
|--------|----------------------|------------------------|
| `idle` | ✅ | ❌ |
| `dryRunRunning` | ❌ | ❌ |
| `previewUnsafe` | ✅ | ❌ |
| `snapshotStale` | ✅ | ❌ |
| `overBatchLimit` | ✅ *(hint limite)* | ❌ |
| `previewSafe` | ✅ *(ricalcolo)* | ✅ *(se snapshot valido e regole §8)* |
| `pushReady` | ❌ o ✅ *(solo ricalcolo — EXECUTION)* | ✅ *(con conferma)* |
| `pushRunning` / `readBackRunning` | ❌ | ❌ |
| `verifiedSuccess` | ✅ *(manuale — v. sotto)* | ❌ |
| `verificationUnknown` | ✅ | ❌ |
| `failedConflict` / `failedValidation` / `failedNetwork` | ✅ *(ricalcolo/diagnosi)* | ❌ |
| `cancelled` | ✅ | ❌ |

*`verifiedSuccess` = **unico** successo pieno; `verificationUnknown` **≠** successo (**D51-14**).*

### Idempotenza post-success *(v1 — manuale)*

- Dopo **`verifiedSuccess`**: **non** rilanciare dry-run **automaticamente** (default TASK-051 v1), salvo **decisione esplicita** documentata in EXECUTION.
- UI: testo positivo + hint **«Ricalcola anteprima: atteso no-op»**; l’utente preme **manualmente** «Calcola anteprima».
- **Motivazione**: meno chiamate remote automatiche; UX controllata; log più leggibili; no confusione con “sync generale”.
- Test mock (**T51-05** e affini): con righe già presenti in remoto, il dry-run deve classificare **`alreadyPresentRemote`** / **ready=0** correttamente.

### Error taxonomy → stato / azione UX

| Condizione | Stato UI | Azione |
|------------|-----------|--------|
| Unique / race remota (**D51-06**) | `failedConflict` | **Ricalcola anteprima**; **no** retry push; **no** upsert |
| Insert OK ma read-back timeout/errore possibile (**D51-14**) | `verificationUnknown` | **Ricalcola anteprima**; **no** “success” pieno |
| Snapshot invalidato | `snapshotStale` | **Ricalcola anteprima** |
| Candidati **`>`** limite v1 (**D51-04**) | `overBatchLimit` | **No** push; multi-batch = **task futuro** |
| Validazione payload / mismatch DDL | `failedValidation` o **BLOCKED** | Stop operativo; no workaround silenziosi |
| `Task` cancellato (**D51-11**) | `cancelled` | **Mai** successo |

### Messaggistica e accessibilità *(sintesi)*

- **Priorità comunicazione:** come **«Scelta UX preferita»**; footer statico anti-sync sempre visibile nel § stesso.
- **`ProgressView`** vedi sopra; stati ricorrenti → **footer** dinamico o inline, non solo `alert`.
- **D51-14**: copy dedicata IT/EN/ES/zh-Hans; **mai** badge “completato” pieno.
- **Accessibilità:** Dynamic Type; VoiceOver per badge DEBUG/Manuale; **motivo** disabilitazione in footer o `accessibilityHint` (stale / over limit / unsafe / …).

---

## 11. Test plan XCTest

| # | Tipo | Descrizione |
|---|------|-------------|
| T51-01 | Puro / mock | Push: **blocco** senza dry-run safe / senza snapshot *(stub)*. |
| T51-02 | Puro / mock | Insert payload: campi obbligatori DDL; **nessun** `id` inviato se DDL con default server *(scenario mock)*. |
| T51-03 | Puro / mock | Read-back **exact-match** dopo insert finto *(tutte le righe)*. |
| T51-04 | Puro / mock | `unsafePartialRemoteDedupe` → push **non invocato**. |
| T51-05 | Puro / mock | Idempotenza dry-run: righe già remote → `alreadyPresentRemote`. |
| T51-06 | Puro / mock | **Snapshot**: cambio **fingerprint** candidate *(hash)* → push invalidato / bottone off. |
| T51-07 | Puro / mock | **Snapshot stale**: simula mutazione locale/auth/baseline → push disabilitato senza nuovo dry-run. |
| T51-08 | Puro / mock | **Batch limit**: candidate count **>** limite v1 → push **non invocato**. |
| T51-09 | Puro / mock | **Unique conflict** simulato → errore controllato, **no** retry, **no** upsert. |
| T51-10 | Puro / mock | Read-back: **riga mancante** → esito failure (non success). |
| T51-11 | Puro / mock | Read-back: **prezzo mismatch** normalizzato → failure. |
| T51-12 | Static / grep | Un solo audit anti-scope su file toccati *(§12)*. |
| T51-13 | Regressione | Suite TASK-050, TASK-049, TASK-048 mirate. |
| T51-14 | Puro / mock | Payload **`owner_user_id`**: coerente con utente mock **o** assente se gestito DB/default *(scenari D51-12)*. |
| T51-15 | Puro / mock | Normalizzazione **`type`**: da valori non canonici a **`PURCHASE`/`RETAIL`** come pipeline esistente. |
| T51-16 | Puro / mock | **`effectiveAt`**: mismatch canonico ⇒ blocco o failure di confronto *(no silent ok)*. |
| T51-17 | Puro / mock | **`price`**: due `Double` “uguali” in senso decimale ma non in confronto naive — normalizzazione evita falsi mismatch. |
| T51-18 | Puro / mock | Insert OK simulato + **read-back timeout/errore** ⇒ stato **verification unknown (D51-14)**, **no** retry automatico. |
| T51-19 | Puro / mock | **Doppio tap** rapido su push ⇒ **una** chiamata insert (o mock conteggio 1). |
| T51-20 | Puro / mock | **Cancellation** durante push/read-back ⇒ stato **non** success. |
| T51-21 | UI / VM test | Push disabilitato: ViewModel espone **motivo** *(stale / over limit / unsafe)* per footer/inline/accessibility. |

### Raggruppamento implementativo *(ordine suggerito per Codex)*

| Gruppo | Test | Focus |
|--------|------|--------|
| **A** — Snapshot / stato / UI | T51-01, T51-06, T51-07, T51-08, T51-19, T51-20, T51-21 | VM **D51-15**, CTA, concorrenza → dopo o in parallelo a servizio mockato. |
| **B** — Service / payload / schema | T51-02, T51-03, T51-09, T51-10, T51-11, T51-14, T51-15, T51-16, T51-17, T51-18 | Logica pura **prima** (più stabile). |
| **C** — Regressioni | T51-05, T51-12, T51-13 | Dopo A/B dove dipendono. |

Scopo: implementare **B** → poi **A/C**; **nessun** test **deve** dipendere da rete reale.

### Rete / smoke *(fuori obbligo CI)*

- Validazione TASK-051: principalmente **mock / XCTest**.
- Eventuale **smoke live** *(write reale)*: solo **manuale**, esplicita, **separata** da build/CI; ambiente/progetto Supabase **autorizzato** dall’utente.
- **Vietato:** write remoto automatico durante build o test; test che falliscono senza rete o che inviano dati reali in pipeline CI.

*(Integrazione rete live nei test: **opzionale**; default **mock**.)*

---

## 12. Checklist anti-scope *(grep / review)*

Prima di REVIEW / DONE:

- [ ] Nessuna occorrenza introdotta: `record_sync_event`, `sync_events`, `outbox` *(nome o pattern dominio)*, `realtime`, `backgroundTask` push prices.
- [ ] Nessuna migration `.sql` nuova/modificata nel repo iOS *(clone Supabase **non** modificato in TASK-051)*.
- [ ] Nessun `service_role` / bypass RLS per read-back.
- [ ] Nessun riferimento a modifica **Android**.
- [ ] Nessun `.rpc(` di scrittura non prevista; solo `insert` mirato `inventory_product_prices`.
- [ ] Nessun `update`/`delete` SwiftData su `ProductPrice` / `Product` prezzi correnti.
- [ ] Copia UI: nessuna stringa **Sync** / **Upload all** / **Carica tutto** come CTA push *(IT/EN/ES/zh-Hans)*.
- [ ] **Grep anti-scope** eseguito **una sola volta** sui file toccati; esito documentato in review *(niente duplicazione CA come “grep ripetuto”)*.

---

## 13. Criteri di accettazione *(contratto — post-EXECUTION)*

**Documentazione / architettura (planning applicato)**
- [ ] **§8.3**: gate pre-codice *(DDL, **D51-03**, **D51-12**, **D51-13**, limite batch **D51-04**, fingerprint/snapshot)* chiuso e **documentato in Execution** prima di merge review.
- [ ] **D51-15**: stato unico VM **documentato** *(nomi/enum in EXECUTION; v. **§8.4**)*; mapping a CTA **§10** rispettato.
- [ ] **D51-16**: **`OptionsView`** senza chiamate/API Supabase dirette; solo VM + servizi.
- [ ] **§8.1**: fingerprint su tuple **ordinate** *(remoteProductId → type → effectiveAtCanonico → priceCanonico)*; niente PII superflua; riuso fingerprint TASK-050 se equivalente.
- [ ] **§8.2**: log/review **privacy-safe** (no barcode/prezzi/nomi piena riga in log casuali).
- [ ] Post-success: **nessun** dry-run automatico **v1** (solo hint + azione manuale **«Calcola anteprima»**) salvo decisione esplicita in **EXECUTION**.
- [ ] Taxonomia errori **§10** ↔ stati UI coerenti (`failedConflict`, `verificationUnknown`, …).
- [ ] Duplicazioni indebite tra §8 / §9 / §13 / §14 assenti *(toleranza: sintesi + rimandi)*.

**Build / qualità**
- [ ] **Build Debug** PASS.
- [ ] **Build Release** PASS.
- [ ] **XCTest** mirati TASK-051 *(incl. T51-14…T51-21 ove applicabile)* PASS.
- [ ] **Regressioni** TASK-048 / TASK-049 / TASK-050 PASS.
- [ ] **`git diff --check`** PASS.
- [ ] **`plutil`** su **IT / EN / ES / zh-Hans** PASS.
- [ ] **Checklist §12** (grep anti-scope **una tantum**) PASS.

**Sicurezza dominio / schema**
- [ ] **D51-03 `id`**: decisione documentata dopo DDL reale; **no** DONE se ambiguo.
- [ ] **D51-12 ownership**: documentato se `owner_user_id` è in payload o no; se richiesto → solo sessione; **no** DONE se ownership/RLS non chiari.
- [ ] **D51-13 normalizzazione**: stessa pipeline TASK-049/050 per type / effectiveAt / price; drift documentato o risolto prima di DONE.

**Comportamento push / verifica**
- [ ] **Dry-run safe** + **snapshot D51-10** valido prima del push; push **off** se **stale**.
- [ ] **D51-04**: **un solo** batch v1 entro limite; errore batch ⇒ **no** successo parziale orchestrato; oltre limite ⇒ fail-closed UX.
- [ ] **read-back exact-match** su tutte le candidate attese; **no** successo parziale silenzioso.
- [ ] **D51-14**: stato *verification unknown* gestito *(UI+copy)*; **≠** DONE finché non chiuso da read-back riuscito **o** no-op al dry-run successivo.
- [ ] **D51-06** unique: no retry auto, no upsert.
- [ ] **D51-11**: anteprima **≠** push concorrenti; doppio tap / cancellation coperti da **test** *(T51-19…T51-20)* **o** evidenza review esplicita.

**UX / accessibilità / copy**
- [ ] **§10**: Avanzata **collapsabile**, primario **«Calcola anteprima»** dove applicabile; push **secondario** + **`confirmationDialog`**; **no** CTA Sync; successo sobrio (**«Push verificato»**); **D51-14** con copy **quattro** lingue; motivo disabilitazione visibile *(footer/hint)*; Dynamic Type / VoiceOver badge.

**Dati locali**
- [ ] **Nessun** aggiornamento `Product.purchasePrice` / `Product.retailPrice`.
- [ ] **Nessuna** mutazione SwiftData storico non prevista **§7 bis**.

---

## 14. Executor quick path *(sintesi operativa — non sostituisce §8–13)*

**Prerequisito:** checklist **E0** / §8.3 nel file **Execution** = **completata** prima di **qualsiasi** implementazione Swift *(passi 4–6)*; se **E0** non è **PASS** → **STOP**.

1. `git fetch` e verifica **`HEAD`** allineato al lavoro *(come §3)*.
2. Leggi DDL/migrazioni **§5** e chiudi **D51-03**, **D51-12**, **D51-13** *(gate **§8.3**)*.
3. Rileggi **`SupabaseProductPricePushDryRunService`** / tipi TASK-050; **riusa** snapshot/fingerprint se equivalente (**§8.1**).
4. Implementa **insert-only** + read-back **exact-match** *(servizio **§8.4**)*.
5. Implementa stato **D51-15** + UI **§10** *(Avanzata/DEBUG)*.
6. XCTest **§11** (gruppi A→B→C) + **§12** una tantum.
7. **Non** passare a **DONE** senza **REVIEW** / **§16**.

---

## 15. Handoff execution corrente

- **Prossima azione immediata:** chiudere **§8.3** — **E0 Pre-code gate obbligatorio** nella sezione **Execution** *(checklist)*.
- **Codex** deve leggere: DDL Supabase locale *(clone migrazioni / §5)* e codice **TASK-048 / TASK-049 / TASK-050** *(servizi dry-run, normalizzazione, preview)*.
- **Prima patch Swift ammessa solo dopo** aver documentato in **Execution** *(campi testuali + checkbox **E0**)*:
  - **D51-03** — `id`;
  - **D51-12** — `owner_user_id` / RLS;
  - **D51-13** — normalizzazione `type` / `effectiveAt` / `price` allineata a TASK-049/050;
  - **D51-04** — batch limit effettivo v1 *(valore + motivazione)*;
  - fingerprint/snapshot — **riuso** TASK-050 o **nuova** implementazione *(motivata)*.
- Dopo **E0** completato: seguire **§14** per implementazione; **non** DONE senza **§16**.

---

## 16. Review checklist *(Claude / Reviewer)*

- [ ] Dry-run + **snapshot D51-10** non bypassabili; CTA push spenta se **stale**.
- [ ] Solo `candidate`; **batch** e **D51-04** rispettati.
- [ ] Read-back **exact-match** obbligatorio; mismatch o riga mancante → **non APPROVED**.
- [ ] **D51-06** / unique → errore esplicito, **no** upsert.
- [ ] **§7 bis** rispettato *(nessuna mutazione locale post-success)*.
- [ ] **D51-11**: `MainActor`; **nessun** parallelismo anteprima vs push; doppio tap/cancellation ⇒ **non** successo falso.
- [ ] **D51-12 / D51-13** rispettati e documentati; read-back **senza** `service_role`.
- [ ] **D51-14**: UX+copy; **non APPROVED** se marcheno DONE con verifica ancora incerta.
- [ ] **D51-15** / **§10**: mapping stato → CTA e messaggi coerenti.
- [ ] **§8.2**: log di review **privacy-safe** (nessun dump prezzi/barcode/nomi).
- [ ] **D51-16**: nessuna logica Supabase in **`OptionsView`** (solo VM/servizi).
- [ ] Anti-scope **§12** *(grep una tantum)* + insert-only `inventory_product_prices`.
- [ ] Copy **no-sync** **IT/EN/ES/zh-Hans**.
- [ ] **TASK-048/049/050** non regressi.

---

## Planning (Claude) — sezioni operative standard

### Analisi
Rinvio a **§8** (D51-03…D51-16) e **§10**: push singolo verificato, snapshot **§8.1**, incertezza **D51-14**, stati **D51-15**.

### Approccio proposto
Rinvio a **§9**; in sintesi: dry-run + snapshot → insert **D51-04** → read-back **D51-05**; servizi TASK-049/050; UI **§10**.

### File da modificare *(indicativi — nomi §8.4)*
- Nuovo: `SupabaseProductPriceManualPushService.swift` *(o estensione minima servizio esistente — **D51-16**)*.
- Modifica: `SupabaseInventoryService.swift` *(solo se necessario)*, `OptionsView.swift`, `Localizable.strings` ×4, test; ViewModel/controller **`ProductPriceManualPushDebugViewModel`** o equivalente pattern progetto.

### Rischi identificati
- DDL **`id`** o **ownership/RLS** ambigui → **BLOCKED**.
- **Drift** normalizzazione vs TASK-049/050 → STOP e allineamento.
- Read-back impossibile o incerto (**D51-14**) → **non DONE** fino a risoluzione.
- Superamento batch / assenza fail-closed UX → rischio operativo.

### Rischi rimasti / follow-up *(fuori scope)*
- Multi-lotto automatico, ottimizzatore bulk, retry persistente, `sync_events`, realtime.

### Handoff → Execution
- **Override ricevuto:** TASK-051 passa ad **EXECUTION controllata**; prima attività **E0** — pre-code gate **§8.3** *(nessuna patch Swift finché la checklist **E0** non è compilata)*.
- **Prossimo agente**: Codex / Executor.
- **Azione consigliata**: completare **E0** → poi **§14** / **§9** / **§11**.

---

## Execution (Codex) — avvio controllato

### E0 — Pre-code gate obbligatorio

*(Compilare **Codex**; allineato a **§8.3**.)*

- [x] Repo aggiornata e **HEAD** verificato.
- [x] DDL reale **`inventory_product_prices`** letto.
- [x] **D51-03** `id` chiusa *(decisione documentata)*.
- [x] **D51-12** `owner_user_id` / RLS chiusa *(decisione documentata)*.
- [x] **D51-13** normalizzazione confermata contro TASK-049 / TASK-050.
- [x] **D51-04** batch limit scelto e motivato.
- [x] Fingerprint/snapshot TASK-050 verificato: riuso o nuova implementazione motivata.
- [x] Nessuna ambiguità residua E0: **PASS**, codice Swift ammesso solo entro le decisioni sotto.

#### Evidenze E0 — 2026-05-06

- **Repo / HEAD**: eseguito `git fetch origin main`; branch `main`; `HEAD` locale `17315a73d8db21bfe429d22b670b14d079c30b2d` = `origin/main` `17315a73d8db21bfe429d22b670b14d079c30b2d`. Working tree già non pulita per tracking TASK-051/MASTER (`docs/MASTER-PLAN.md` modificato, file task TASK-051 non tracciato): preservare, non revertire.
- **DDL reale letto**: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260417200000_task016_inventory_product_prices.sql`; verifica aggiuntiva delete restriction in `20260421120000_task038_restrict_authenticated_delete_inventory.sql`.
- **D51-03 `id`**: DDL reale `id uuid PRIMARY KEY` **senza default server-side**. Il client TASK-051 deve inviare `id` deterministico, non casuale, derivato dalla chiave logica canonica. Decisione execution: UUID deterministico da namespace TASK-051 + tuple canonica `owner_user_id|product_id|type|effective_at`; vietato `UUID()` casuale per payload push.
- **D51-12 `owner_user_id` / RLS**: DDL `owner_user_id uuid NOT NULL REFERENCES auth.users(id)`; policy `inventory_product_prices_insert_owner` usa `WITH CHECK (auth.uid() = owner_user_id)`, select usa `USING (auth.uid() = owner_user_id)`. Il payload deve includere `owner_user_id` preso solo da `session.user.id`; read-back owner-scoped tramite sessione/RLS, nessun `service_role`.
- **D51-13 normalizzazione**: confermata contro codice TASK-049/050:
  - `type`: `SupabasePullPreviewNormalizer.normalizedPriceType` normalizza internamente a `purchase` / `retail`; payload remoto usa `ProductPricePushDryRunCandidatePayload.remoteType` = `PURCHASE` / `RETAIL`.
  - `effectiveAt`: `ProductPriceEffectiveAtCanonicalizer.canonicalString` usa UTC `yyyy-MM-dd HH:mm:ss`; read-back può parsare canonico e ISO già come TASK-049.
  - `price`: `PriceCanonicalizer.canonicalAmount` arrotonda a 3 decimali con `Decimal` / `.plain`; confronto exact-match deve usare `ProductPriceCanonicalAmount`, non raw `Double`.
- **D51-04 batch limit v1**: scelto **100 righe massimo**. Motivazione: coincide con default batch TASK-050, limita blast radius del primo push live e rispetta planning v1 single-batch; se `readyCandidates > 100` la UX deve fallire chiusa senza inviare subset.
- **Fingerprint/snapshot TASK-050**: verificato codice TASK-050. `ProductPricePushDryRunPlan` contiene candidate/payload normalizzati, `generatedAt`, session snapshot e dedupe status, ma **non** espone un fingerprint snapshot equivalente a §8.1. Decisione execution: implementare snapshot volatile nuovo riusando i payload normalizzati TASK-050; fingerprint su tuple ordinate `remoteProductId -> type -> effectiveAtCanonico -> priceCanonico`, includendo sessione/baseline/dedupe/count come guardia di validità ViewModel. Nessun salvataggio in UserDefaults/file/SwiftData.

**Fino al completamento di E0:** non implementare `SupabaseProductPriceManualPushService`, non modificare `OptionsView`, non aggiungere test e non eseguire **write remoto**.

#### Obiettivo compreso / piano minimo prima della patch Swift

- **Obiettivo compreso**: aggiungere push live manuale controllato solo per storico prezzi `inventory_product_prices`, vincolato a dry-run TASK-050 safe, snapshot volatile valido, insert-only single-batch, read-back exact-match, UI DEBUG in OptionsView e XCTest mock senza rete reale.
- **File Swift previsti**: `SupabaseProductPricePushDryRunService.swift`, nuovo/esteso servizio push manuale, `SupabaseInventoryService.swift`, `OptionsView.swift`, `Localizable.strings` IT/EN/ES/zh-Hans, XCTest TASK-051 e regressioni TASK-048/049/050 mirate.
- **Piano minimo**: riusare payload/normalizzatori TASK-050; aggiungere DTO payload insert + UUID deterministico; aggiungere service insert/read-back mockabile; aggiungere VM volatile anti-stale/anti-double-tap; collegare UI nativa Avanzata/DEBUG; coprire con XCTest mock e verifiche finali richieste.

*(Sezioni EXECUTION successive — implementazione, test, evidenze — solo dopo **E0** PASS.)*

### Implementazione — 2026-05-06

#### Obiettivo compreso

Implementato il push live manuale controllato solo per `inventory_product_prices`: dry-run TASK-050 safe obbligatorio, snapshot volatile/fingerprint, insert-only single-batch max 100, read-back exact-match, stati VM D51-15 e UI DEBUG in `OptionsView`. Nessun push automatico, nessun outbox/retry persistente, nessun `sync_events`, nessuna mutazione SwiftData post-success.

#### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-051-supabase-productprice-push-live-manuale-controllato-ios.md`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260417200000_task016_inventory_product_prices.sql`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260421120000_task038_restrict_authenticated_delete_inventory.sql`
- `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`
- `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/*/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests.swift`

#### Piano minimo applicato

- Riutilizzare normalizzazione e dry-run TASK-049/TASK-050.
- Aggiungere servizio mockabile per payload insert, UUID deterministico, insert-only e read-back exact-match.
- Aggiungere VM volatile per snapshot corrente, stale state, CTA, progress, cancellation e anti doppio tap.
- Collegare una UI SwiftUI nativa in `OptionsView` dentro sezione Avanzata / DEBUG.
- Coprire il comportamento con XCTest mock senza rete reale e verifiche statiche finali.

#### Modifiche fatte

- Aggiunto `SupabaseProductPriceManualPushService.swift` con:
  - `ProductPriceManualPushPayload`, `ProductPriceManualPushSnapshot`, result/error/verification types;
  - fingerprint privacy-safe su tuple ordinate `productID|type|effectiveAt|priceCanonical`;
  - UUID deterministico client-side coerente con D51-03;
  - fail-closed su dry-run non safe, snapshot stale, candidati zero/non validi e batch `> 100`;
  - insert-only + read-back exact-match; read-back incerto = `verificationUnknown`, non success.
- Aggiunto `ProductPriceManualPushDebugViewModel.swift` con stato volatile D51-15, anti parallelismo preview/push, invalidazione snapshot, cancellation e guardia doppio tap.
- Esteso `SupabaseInventoryService.swift` con solo:
  - `insertProductPriceManualPushPayloads(_:)` su `inventory_product_prices`;
  - `fetchProductPricesForManualPushVerificationPage(...)` owner-scoped/session-scoped per read-back;
  - mapping unique conflict verso errore controllato. Nessun upsert/update/delete/RPC.
- Aggiornato `OptionsView.swift`:
  - `OptionsView` mostra UI e invia azioni al ViewModel; nessuna logica Supabase diretta nella View;
  - nuova sezione localizzata “Avanzata” con `DisclosureGroup`, titolo “Push manuale storico prezzi”, badge “Manuale” e “DEBUG”;
  - CTA “Calcola anteprima” e “Esegui push manuale” con `confirmationDialog`;
  - `ProgressView` durante dry-run/push/read-back;
  - footer sempre visibile anti-sync;
  - success sobrio “Push verificato” + hint “Ricalcola anteprima: atteso no-op”.
- Aggiornati `Localizable.strings` IT/EN/ES/zh-Hans per copy UI, error taxonomy e confirmation dialog; nessuna CTA “Sync”, “Upload all”, “Carica tutto”.
- Aggiunti XCTest mock in `SupabaseProductPriceManualPushServiceTests.swift`.
- Aggiornato il test statico TASK-048 in `SupabaseProductPricePreviewServiceTests.swift` per limitare l’audit zero-write al metodo preview read-only, senza bocciare l’insert scoped TASK-051.

#### Decisioni D51 chiuse in execution

- **D51-03 `id`**: DDL senza default server-side; payload invia UUID deterministico da namespace TASK-051 + tuple canonica `owner_user_id|product_id|type|effective_at`. No `UUID()` casuale per push.
- **D51-12 owner/RLS**: `owner_user_id` nel payload da `session.user.id`; read-back owner-scoped via sessione/RLS; nessun `service_role`.
- **D51-13 normalizzazione**: riuso TASK-049/TASK-050 per type, effectiveAt e price; compare su canonical amount, non raw `Double`.
- **D51-04 batch**: limite v1 = 100 righe; oltre limite = stato `overBatchLimit`, nessun subset.
- **Snapshot/fingerprint**: nuova implementazione motivata perché TASK-050 non espone fingerprint equivalente; snapshot solo in RAM/ViewModel, non persistito.

#### Check eseguiti

- ✅ ESEGUITO — **Build Debug compila**: `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — **Build Release compila**: `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — **Nessun warning nuovo introdotto verificabile**: build riuscite; warning visibili non introdotti da TASK-051:
  - `SupabaseProductPriceApplyService.swift:771` Swift 6 `issueLimit`, già documentato come residuo TASK-049/TASK-050;
  - warning Xcode `Metadata extraction skipped. No AppIntents.framework dependency found.`
- ✅ ESEGUITO — **XCTest mirati TASK-051**: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests` → **TEST SUCCEEDED**, 14 test passati.
- ✅ ESEGUITO — **Regressioni TASK-048 / TASK-049 / TASK-050**: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — **`git diff --check`**: PASS, nessun output; nuovi file non tracciati controllati anche con `git diff --check --no-index /dev/null <file>` senza output whitespace.
- ✅ ESEGUITO — **`plutil` Localizable.strings IT/EN/ES/zh-Hans**: PASS, tutti `OK`.
- ✅ ESEGUITO — **Grep anti-scope sui file toccati**: nessuna occorrenza di `record_sync_event`, `sync_events`, `outbox`, `realtime`, `service_role`, `.rpc(`, `backgroundTask`.
- ✅ ESEGUITO — **Modifiche coerenti con planning**: servizio insert-only/read-back, VM volatile, UI Avanzata/DEBUG, test mock; nessuna migration SQL/RLS/RPC, nessun Android, nessun write live in test.
- ✅ ESEGUITO — **Criteri di accettazione verificati**:
  - dry-run safe + snapshot obbligatori;
  - stale/over-limit/unsafe fail-closed;
  - single batch max 100;
  - unique conflict senza retry/upsert;
  - read-back missing/mismatch/unknown non success;
  - `verifiedSuccess` unico successo pieno;
  - owner_user_id da sessione;
  - type/effectiveAt/price normalizzati;
  - doppio tap e cancellation coperti da test.

#### Rischi rimasti

- La validazione live con scrittura reale Supabase resta **fuori execution** e richiede autorizzazione esplicita separata.
- Warning Release preesistente in `SupabaseProductPriceApplyService.swift:771` rimane fuori perimetro TASK-051.
- Warning Xcode AppIntents metadata rimane fuori perimetro TASK-051.
- Multi-batch, retry persistente, no-op live smoke automatico, `sync_events`, outbox, realtime/background sync restano follow-up futuri non attivi.

#### Aggiornamenti file di tracking

- Aggiornato questo file task con E0, decisioni D51, file modificati, check eseguiti, rischi residui e handoff.
- Aggiornato `docs/MASTER-PLAN.md` solo per fase/responsabile/stato avanzamento TASK-051.

### Handoff post-execution — Codex → Claude / Reviewer

- **Stato task**: ACTIVE.
- **Fase attuale**: REVIEW.
- **Responsabile attuale**: Claude / Reviewer.
- **Esito execution**: implementazione completata e verificata con build Debug/Release, XCTest mirati e regressioni, `git diff --check`, `plutil`, grep anti-scope.
- **Richiesta review**: verificare in particolare D51-03 UUID deterministico client-side, D51-12 owner/RLS, D51-13 normalizzazione condivisa, read-back exact-match, UI `OptionsView` senza logica Supabase diretta, e assenza di scope extra.
- **Nota**: non marcare DONE in review senza conferma utente.

## Review (Claude)

### 2026-05-06 — REVIEW severa su override utente *(eseguita da Codex / Reviewer+Fixer)*

- **Esito finale**: **APPROVED_FIXED_DIRECTLY / DONE**.
- **Scope TASK-051 verificato**: implementazione limitata a push manuale controllato di `inventory_product_prices`, dry-run TASK-050 safe obbligatorio, snapshot/fingerprint volatile, insert-only, single batch max 100, read-back exact-match, UI Avanzata/DEBUG e XCTest mock. Nessun write live in test.
- **Anti-scope verificato**: nessun `record_sync_event`, `sync_events`, outbox, realtime/background sync, RPC, `service_role`, migration SQL/RLS, Android, update/delete remoto, update/delete SwiftData `ProductPrice`, modifica `Product.purchasePrice` / `Product.retailPrice`, salvataggio snapshot in UserDefaults/file.
- **D51-03 `id`**: DDL reale confermato `id uuid PRIMARY KEY` senza default server-side. Il payload live usa UUID deterministico da tuple canonica `owner_user_id|product_id|type|effective_at`; nessun `UUID()` casuale nel servizio push/VM.
- **D51-12 owner/RLS**: `owner_user_id` deriva dal dry-run session-scoped e viene ulteriormente verificato contro la sessione Supabase corrente prima di insert/read-back. Read-back resta owner-scoped via sessione/RLS; nessun bypass.
- **D51-13 normalizzazione**: `type` remoto solo `PURCHASE` / `RETAIL`; `effectiveAt` e `price` riusano normalizzatori TASK-049/050; exact-match usa canonical amount, non raw `Double`.
- **Snapshot/fingerprint**: snapshot solo in RAM/VM; fingerprint su tuple ordinate `remoteProductId -> type -> effectiveAtCanonico -> priceCanonico`; push disabilitato su stale/unsafe/over-limit/no candidates e dopo stati terminali non success.
- **Service/VM/UI**: service piccolo e mockabile; no upsert/retry; unique conflict controllato; read-back missing/mismatch/unknown non success; VM `@MainActor` con stato unico D51-15, anti double-tap/cancellation; `OptionsView` solo UI/azioni, senza logica Supabase diretta.
- **UI/localizzazioni**: sezione “Avanzata” con `DisclosureGroup`, badge Manuale/DEBUG, CTA “Calcola anteprima” primaria, CTA “Esegui push manuale” secondaria con `confirmationDialog`, footer anti-sync sempre visibile, `ProgressView`, successo “Push verificato” e hint no-op. IT/EN/ES/zh-Hans presenti e lint OK.

**Problemi trovati e fix diretti:**
- Hardening owner/RLS: il client ora confronta l'owner richiesto con la sessione Supabase corrente prima di dedupe dry-run owner-scoped, insert payload e read-back manuale.
- UX Dynamic Type: i pulsanti del blocco manual push ora usano `ViewThatFits`, passando da riga a colonna su larghezze strette.
- Test rafforzati: aggiunti casi per filtro owner/product read-back, mismatch `type`/`effective_at`, e UUID deterministico che cambia al variare della tuple canonica.

**Comandi REVIEW eseguiti:**
- ✅ `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests` → **TEST SUCCEEDED**, 16 test passati.
- ✅ Regressioni TASK-048 / TASK-049 / TASK-050 + TASK-051: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests` → **TEST SUCCEEDED**, 70 test passati.
- ✅ `git diff --check` → PASS; nuovi file untracked controllati anche con `git diff --check --no-index /dev/null <file>` → PASS.
- ✅ `plutil -lint` su `Localizable.strings` IT / EN / ES / zh-Hans → OK.
- ✅ Grep anti-scope sui file Swift/strings/test toccati → nessuna occorrenza di `record_sync_event`, `sync_events`, `outbox`, `realtime`, `service_role`, `.rpc(`, `backgroundTask`.
- ✅ Audit no-write locale/prezzi correnti sui file TASK-051 → nessuna mutazione `Product.purchasePrice`, `Product.retailPrice`, `ProductPrice` SwiftData o snapshot persistente.
- ⚠️ Warning residui non attribuiti a TASK-051: warning Swift 6 preesistente in `SupabaseProductPriceApplyService.swift:771` su `issueLimit`; warning Xcode AppIntents metadata extraction.

**Rischi residui / follow-up non attivi:**
- Smoke live reale con write Supabase non eseguito in review; resta follow-up manuale separato e non blocca DONE.
- Multi-batch, retry persistente, `record_sync_event` / `sync_events`, outbox, realtime/background sync, tombstone outbound e TASK-052 futuri **non** sono attivati automaticamente.

## Fix (Codex)

### 2026-05-06 — Fix diretti dentro REVIEW

- Aggiunto hardening owner/session in `SupabaseInventoryService`: dedupe dry-run, insert manuale e read-back manuale non procedono se l'owner richiesto non coincide con la sessione Supabase corrente.
- Rifinita la UI manual push in `OptionsView` con `ViewThatFits` per pulsanti più robusti a Dynamic Type/larghezze strette.
- Rafforzata `SupabaseProductPriceManualPushServiceTests` con 3 coperture aggiuntive mirate a D51-03/D51-12/D51-13.

**Chiusura:** TASK-051 marcato **DONE / Chiusura** su conferma esplicita dell'utente nel prompt REVIEW, con esito **APPROVED_FIXED_DIRECTLY**. Smoke live reale resta separato e manuale.
