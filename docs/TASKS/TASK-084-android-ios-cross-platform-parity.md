# TASK-084 — Parità Android ↔ iOS (Supabase condiviso)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-084 |
| **Titolo** | Parità Android ↔ iOS (execution read-only cross-platform via Supabase) |
| **File task** | `docs/TASKS/TASK-084-android-ios-cross-platform-parity.md` |
| **Stato** | DONE |
| **Fase attuale** | CHIUSURA |
| **Responsabile attuale** | Codex / Reviewer |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 21:23 -0400 — REVIEW/CHIUSURA: TASK-084 chiuso DONE come review documentale della slice read-only P84-A/P84-B/P84-C; nessuna parità runtime dichiarata |
| **Ultimo agente** | Codex / Reviewer |
| **Repo iOS target** | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| **Repo Android riferimento** | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| **Supabase locale riferimento** | `/Users/minxiang/Desktop/MerchandiseControlSupabase` *(schema/contratti: solo lettura documentale in fase PLANNING; nessun write live in questo task)* |

---

## Dipendenze

- **Dipende da:** **TASK-083 DONE / Chiusura** — chiusura documentale corretta dopo preflight manifest sandbox incompleto; nessuna evidenza runtime smoke E2E PASS da TASK-083 da riutilizzare come gate di parità.
- **Base iOS Supabase mutativa (solo contesto, non riapertura):** **TASK-078 … TASK-083** come sequenza **DONE / Chiusura** che ha definito pull apply, push catalogo, ProductPrice, drain outbox, policy conflitti/timestamp Release; TASK-084 **non riapre** TASK-083 né richiede riesecuzione degli scenari S83 per completare questo planning.
- **TASK-075** resta riferimento metodologico (smoke controllato, dataset sizing, evidenze privacy-safe) ma non è dipendenza bloccante per redigere il manifest P84.
- **TASK-085** resta **TODO / Planning** — **non aperto**, **non promosso**, nessun handoff verso hardening production in questo file.
- **Chiarimento esplicito:** TASK-084 **non riapre** TASK-083; eventuali smoke futuri useranno un **manifest cross-platform dedicato** (vedi sotto), separato dalla campagna S83.

---

## Obiettivo

Definire un **piano concreto verificabile** (solo documentazione in questa fase) per:

1. **Parità funzionale** tra comportamento **Android** (riferimento) e **iOS** (target di modifica futura) quando i dati transitano tramite **Supabase** condiviso.
2. **Aree da coprire nel gap analysis:** catalogo prodotti; fornitori; categorie; prezzi correnti; storico prezzi / `ProductPrice`; import/export database; `sync_events` / outbox; errori, duplicati e conflitti; flussi manuali Supabase (Release); compatibilità **Android → Supabase → iOS** e **iOS → Supabase → Android**.
3. **Esito atteso del planning:** matrice parità, manifest dataset sandbox obbligatorio prima di qualunque execution futura, scenari P84 nominati con stato **PLANNED / NOT RUN**, decisioni D84, rischi — **senza** dichiarare parità reale senza evidenze.

**Nota metodologica:** Android è **solo riferimento funzionale**; **vietato** porting 1:1 Kotlin → Swift come obiettivo di questo task.

---

## Stato iniziale

- **TASK-083** è **DONE / Chiusura** ma lo **smoke runtime end-to-end non è PASS**: preflight ha rilevato **manifest sandbox incompleto** (fixture storiche `TASK045_*` / TASK-075 non coprono ProductPrice + duplicato/conflitto controllato + attività outbox registrabile come richiesto per S83-01…06). **S83-01** resta **BLOCKED** a livello di design esecuzione originale; **S83-02…S83-06** **NOT RUN**.
- **Implicazione per TASK-084:** ogni futura verifica cross-platform deve partire da un **manifest / dataset cross-platform definito, approvato e privacy-safe** — non da “dataset negozio reale” come primo passo e non da assunzioni implicite su fixture incomplete.
- **iOS** ha già una cutline Release per sync mutativa manuale (TASK-078…082); la **parità con Android** non è ancora **dimostrata** con cicli bidirezionali controllati e evidenze nominative.

---

## Fonti da leggere

| Fonte | Ruolo |
|-------|--------|
| **Repo iOS** (`iOSMerchandiseControl`) | Target principale: Swift/SwiftData, servizi Supabase manual sync, import/export |
| **Repo Android** (`MerchandiseControlSplitView`) | Riferimento funzionale: flussi Room/UI equivalenti **senza** obbligo di clonare implementazione |
| **Supabase locale** (`MerchandiseControlSupabase`) | Contratto schema/migrazioni **solo lettura** per allineamento nomi tabelle/policy (PLANNING) |
| **`docs/MASTER-PLAN.md`** | Backlog, sequenza TASK-076…085, stato progetto |
| **TASK-075** … **TASK-083** | File in `docs/TASKS/` — contesto sync mutativa iOS e chiusura TASK-083 |
| **File Android indicativi** (se presenti nel repo Android): `ImportAnalysis.kt`, `ExcelUtils.kt`, `DatabaseViewModel.kt`, `InventoryRepository.kt`, `DatabaseScreen.kt`, `GeneratedScreen.kt`, `ProductPriceSummary.kt`, `ProductWithDetails.kt`, `AppDatabase.kt` | Letture **funzionali** per mapping comportamenti vs schema cloud |

---

## Perimetro planning

**Incluso:** solo **planning** e **gap analysis** documentale; matrice parità; manifest sandbox; scenari P84; decisioni; rischi; handoff verso review planning.

**Escluso in modo assoluto in questo turno e in questa fase fino a handoff EXECUTION esplicito:**

- Execution (Codex), patch codice, smoke runtime
- Codice **Swift** / **SwiftUI** / **SwiftData**
- Codice **Kotlin**
- **SQL live**, migrazioni Supabase applicate al remoto, **write Supabase**
- `xcodebuild` o build obbligatori
- Apertura o promozione **TASK-085**

---

## Fuori perimetro severo

- Porting Kotlin **1:1** → Swift
- Redesign Android
- Modifiche Swift / SwiftUI / SwiftData / `project.pbxproj` / `Localizable.strings`
- Migrazioni Supabase **live**
- Cleanup / reset / truncate / delete dati (locale o remoto)
- Sync automatica / background (`Timer`, `BGTask`, Realtime worker, polling) come strategia per “completare” scenari
- Dataset **negozio reale** come primo step di verifica
- Dichiarare **parità completa** senza evidenze scenario-per-scenario
- Riaprire **TASK-083** o trattare TASK-083 come blocker operativo per redigere questo planning
- Aprire **TASK-085**

---

## Principi UX/UI per la parità Android ↔ iOS

TASK-084 non deve cercare una copia visiva Android. La parità richiesta è **parità di esito utente e dati**, mantenendo una UI iOS nativa e coerente con il resto dell'app.

Regole UX/UI per il planning:

- Parità = stesso risultato comprensibile: cosa è stato creato, aggiornato, saltato, bloccato, registrato o lasciato in attesa.
- iOS può usare `NavigationStack`, sheet SwiftUI, toolbar, card e summary nativi anche se Android usa schermate Compose diverse.
- Copy Release iOS senza gergo tecnico: evitare `outbox`, `RPC`, `RLS`, `payload`, `owner_user_id`, `baseline`, `dry-run` nel testo utente.
- Quando Android mostra dettagli tecnici utili, iOS deve tradurli in messaggi user-facing: **modifiche sul cloud**, **questo dispositivo**, **prezzi**, **attività locali**, **attenzione**, **riprova**, **ricontrolla**.
- Se una scelta UX è ambigua, scegliere la soluzione più sicura per i dati e più chiara per un utente iOS, non quella più simile ad Android.
- I ritocchi UI/UX emersi dal planning vanno registrati come follow-up o criteri di futura execution; **nessuna patch Swift/UI in TASK-084 PLANNING**.

### Regola decisionale UX

Quando Android e iOS differiscono, classificare la differenza così:

| Caso | Decisione planning |
|------|--------------------|
| Android e iOS producono gli stessi dati e lo stesso messaggio utente, ma layout diverso | **ACCEPTED_NATIVE_IOS** |
| iOS rende più chiaro il flusso rispetto ad Android senza perdere dati/funzioni | **ACCEPTED_NATIVE_IOS_IMPROVEMENT** |
| iOS nasconde un esito che Android espone chiaramente | **GAP_UX_VISIBILITY** |
| iOS manca una funzione Android stabile | **GAP_FUNCTIONAL** |
| Android espone dettagli tecnici non adatti alla Release iOS | Tradurre in copy iOS user-facing, non copiare gergo |
| La differenza cambia dati, conteggi, conflitti o storico prezzi | **GAP_DATA_CONTRACT** |

Questa tabella evita di trasformare TASK-084 in redesign UI: la domanda non è “sembra Android?”, ma “l'utente e i dati arrivano allo stesso risultato in modo sicuro e comprensibile?”.

---

## Matrice parità Android ↔ iOS

*Stato colonne: riferimenti Android/iOS indicano **file o servizi tipici** da mappare in fase di review repo; schema Supabase da confermare sul clone locale. **Gap atteso** = ipotesi iniziale da validare, non verdict.*

### Tassonomia gap da usare nella review

Ogni riga della matrice, durante una futura review repo-grounded, deve ricevere una classificazione esplicita:

| Stato gap | Significato |
|-----------|-------------|
| **MATCH** | Android, iOS e Supabase hanno contratto dati/comportamento compatibile |
| **ACCEPTED_NATIVE_IOS** | Differenza UI accettata perché iOS è più nativo ma esito dati/utente equivalente |
| **PARTIAL** | Copertura presente ma incompleta o non verificata end-to-end |
| **MISSING_IOS** | Android ha funzione stabile non presente su iOS |
| **MISSING_ANDROID** | iOS ha funzione utile non presente o non allineata su Android |
| **SCHEMA_GAP** | Supabase non supporta ancora il caso senza backend/schema follow-up |
| **BLOCKED_MANIFEST** | Non verificabile senza record manifest sandbox dedicato |
| **OUT_OF_SCOPE_TASK_084** | Area reale ma da spostare a TASK-085 o task separato |

Regola: una riga senza classificazione esplicita non può contribuire a dichiarare parità.

### Template field mapping Android ↔ Supabase ↔ iOS

Durante la review repo-grounded futura, ogni area P0/P1 della matrice dovrebbe essere trasformata in una mini-tabella campo-per-campo. Questo evita claim generici di parità e rende più facile capire se serve un task iOS, Android o backend.

| Campo | Android | Supabase | iOS | Regola parità | Gap status |
|-------|---------|----------|-----|---------------|------------|
| Identità prodotto | `barcode` / id Room | chiave business + id remoto | `barcode` + remote id se presente | Un prodotto sandbox deve risolversi allo stesso articolo | MATCH / PARTIAL / SCHEMA_GAP |
| Nome prodotto | campo Android equivalente | colonna nome prodotto | campo SwiftData/UI | Normalizzazione spazi/case documentata | MATCH / MISSING_IOS / MISSING_ANDROID |
| Fornitore | FK / nome fornitore | tabella/relazione fornitore | modello Supplier | Nessun orfano FK dopo round-trip | MATCH / PARTIAL |
| Categoria | FK / nome categoria | tabella/relazione categoria | modello Category | Nessun orfano FK dopo round-trip | MATCH / PARTIAL |
| Prezzo corrente | current purchase/retail | derivato o snapshot da storico | current/previous UI | Current e previous devono avere stessa semantica | MATCH / GAP_DATA_CONTRACT |
| Storico prezzo | ProductPrice | `inventory_product_prices` | ProductPrice SwiftData | `effective_at` ordinato e dedupe coerente | MATCH / SCHEMA_GAP |
| Outbox/evento | sync event locale | `sync_events` / RPC | outbox iOS | Stesso domain/eventType semantico | MATCH / PARTIAL / SCHEMA_GAP |

Regola: se non è chiaro quale colonna o modello sia la fonte di verità, classificare PARTIAL o SCHEMA_GAP, non MATCH.

| Area | Android riferimento | iOS stato da verificare | Supabase schema/tabelle coinvolte *(indicativo)* | Gap atteso | Priorità | Note |
|------|---------------------|-------------------------|--------------------------------------------------|------------|---------|------|
| 1. Product | `ProductWithDetails`, `AppDatabase`, repository | SwiftData `Product`, mapping pull/push | `inventory_products` (+ RLS `owner_user_id`) | Campi opzionali, nullability, identità barcode vs remote id | P0 | Allineare chiave business vs PK remota |
| 2. Supplier | ViewModel / DAO | `Supplier`, push/pull | tabella fornitori inventario *(nome da clone)* | Ordine creazione FK vs product | P1 | |
| 3. Category | ViewModel / DAO | `ProductCategory` | tabella categorie inventario | Stesso | P1 | |
| 4. ProductPrice / storico | `ProductPriceSummary`, DAO | `ProductPrice`, servizi TASK-080 | `inventory_product_prices` | `effective_at`, unicità, ordinamento storico | P0 | TASK-080/Vincoli UNIQUE |
| 5. Current / previous price | Modello Android + UI | Campi su `Product` + history | prodotti + righe prezzo | Deriva locale vs snapshot remoto | P0 | Rischio disallineamento UI |
| 6. Import Excel | Flusso import DB Android | `ProductImportViewModel`, `DatabaseView` | N/A locale prima persist | Parità regole parsing vs cloud successivo | P1 | Excel ≠ Supabase diretto |
| 7. Header mapping / alias | `ExcelUtils` | `ExcelAnalyzer` (alias) | N/A | Divergenza alias colon | P1 | TASK-084: confronto funzionale |
| 8. Import analysis | `ImportAnalysis.kt` | `ImportAnalysisView` | N/A | Conteggi errori/aggiornamenti | P1 | |
| 9. Duplicati | Dedup Android | Deduplicazione import iOS | vincoli barcode remoto + locale | Doppio insert / merge | P0 | Legare a P84-10 |
| 10. Errori riga | Righe errore import | Stesso su iOS | N/A | Messaggistica e conteggi | P2 | |
| 11. Export prodotti | Export Android | `DatabaseView` XLSX | N/A | Colonne ordine / tipi | P2 | |
| 12. Export database completo | Backup/export Android | Export iOS completo | N/A | Formato file compatibile reimport | P1 | P84-08 |
| 13. Import database completo | Import Android | Import iOS | N/A | Idempotenza cross-platform | P1 | Manifest: export/reimport |
| 14. Manual entry | UI manual entry | Schede inserimento iOS | N/A | Campi obbligatori | P2 | |
| 15. Barcode scanner | Scanner Android | `BarcodeScannerView` | N/A | Permessi / riacquisizione *(TASK-032 legato)* | P2 | Non bloccare planning P84 |
| 16. History entries | `GeneratedScreen`, storico | `HistoryEntry`, `GeneratedView` | opzionale eventi dominio inventario | Inventario sessione locale vs cloud | P1 | Parità “significato” riga griglia |
| 17. Sync events / outbox | Enqueue/drain Android | Outbox iOS, drain TASK-081 | `sync_events`, RPC `record_sync_event` | Payload domain/eventType, limiti `changed_count` | P0 | Idempotenza `client_event_id` |
| 18. Pull apply | Pull Android | `SupabasePullApplyService` | `inventory_*` lettura | Guard catalog/price | P0 | TASK-078/082 |
| 19. Push catalogo | Push Android | `SupabaseManualPushService` | `inventory_products` upsert | baseline stale, conflict | P0 | TASK-079/082 |
| 20. ProductPrice sync | Prezzi Android | Apply/push prezzi iOS | `inventory_product_prices` | effective_at vs updated_at catalogo | P0 | TASK-080/082 |
| 21. Drain attività | Registrazione eventi | CTA **Registra attività sul cloud** | outbox + RPC | Head-of-line, retry | P1 | TASK-081 |
| 22. Conflitti / timestamp | Resolver Android | `SupabaseSyncPlan` iOS | `updated_at`, `deleted_at`, prezzi | Tombstone, ordering | P0 | TASK-082 |
| 23. UX Release no-jargon | Stringhe Android | IT/EN/ES/zh-Hans iOS | N/A | Lessico diverso accettabile se chiaro | P2 | Parità **esito** non pixel |
| 24. Localizzazioni | Risorse Android | `Localizable.strings` iOS | N/A | Chiavi / plurali | P3 | Fuori patch in questo task |
| 25. Performance dataset medio/grande | Liste paginate Android | SwiftData fetch UI iOS | N/A | Timeout percepito | P2 | Rimando misura a TASK-085 / override |

---

## Manifest dataset cross-platform *(sandbox, privacy-safe)*

Obiettivo: evitare il fallimento TASK-083 per **manifest incompleto** — prima di qualunque future execution smoke/parità, definire un insieme minimo di **record fittizi** (barcode inventati, nomi generici, prezzi simbolici) con **conteggi attesi** e **direzioni** chiare. Nessun dato negozio reale.

### Convenzione dati sandbox consigliata

Per rendere il manifest riconoscibile e non confonderlo con dati reali, usare valori con prefisso stabile:

- Barcode: `P84SANDBOX0001`, `P84SANDBOX0002`, ...
- Nome prodotto: `P84 Sandbox Product 01`, `P84 Sandbox Product 02`, ...
- Fornitore: `P84 Sandbox Supplier`
- Categoria: `P84 Sandbox Category`
- Prezzi: valori simbolici piccoli e riconoscibili, ad esempio `101`, `202`, `303`, mai listini reali.
- Timestamp: valori controllati e documentati, non “now” implicito, quando serve testare `effective_at` / `updated_at`.

Se una piattaforma normalizza barcode, nomi o prezzi in modo diverso, la normalizzazione va documentata come parte dello scenario, non corretta a mano durante l'esecuzione.

### Regole di normalizzazione da decidere prima della execution

Prima di usare il manifest, la review deve decidere e documentare queste regole, altrimenti la futura execution rischia di confrontare dati non equivalenti:

| Area | Regola da fissare |
|------|-------------------|
| Barcode | Conservare stringa originale o normalizzare trim/zero iniziali? |
| Nome prodotto | Trim, case sensitivity, doppio spazio, secondo nome prodotto |
| Prezzi | Arrotondamento, decimali, valuta, valori null/zero |
| Timestamp | Timezone, formato, confronto `effective_at` / `updated_at` |
| Fornitore/categoria | Matching per id remoto, nome normalizzato o entrambi |
| Import Excel | Header alias equivalenti Android/iOS e righe decorative |
| Export/import DB | Ordine colonne obbligatorio o mapping per header |

Decisione consigliata: preferire normalizzazioni esplicite e riproducibili nel manifest, non correzioni manuali durante lo smoke.

| # | Elemento manifest | Descrizione | Direzione / uso |
|---|-------------------|-------------|-------------------|
| M1 | Prodotto invariato | Esiste su entrambe le app + cloud, nessuna modifica nel test | Baseline lettura |
| M2 | Prodotto nuovo creato su **Android** | barcode univoco sandbox | Android → Supabase → iOS |
| M3 | Prodotto nuovo creato su **iOS** | barcode univoco sandbox | iOS → Supabase → Android |
| M4 | Prodotto modificato su **Android** | es. nome o stock | Android → Supabase → iOS (pull/UX) |
| M5 | Prodotto modificato su **iOS** | es. nome o stock | iOS → Supabase → Android |
| M6 | Fornitore nuovo | record sandbox | FK verso prodotto M2/M3 |
| M7 | Categoria nuova | record sandbox | FK |
| M8 | Prezzo acquisto modificato | valore decimale simbolico | Storico + current |
| M9 | Prezzo vendita modificato | idem | Storico + current |
| M10 | Storico prezzo con **`effective_at`** | almeno due righe storico controllate | ProductPrice ordering |
| M11 | Duplicato barcode **controllato** | scenario che esercita dedupe/skip | Alline TASK-082/080 |
| M12 | Conflitto timestamp **controllato** | due writer sandbox sequenziali | Policy TASK-082 |
| M13 | Record eliminato / **tombstone** | *se supportato dallo schema* | `deleted_at` o equivalente — se non supportato: **gap backend** documentato |
| M14 | Attività outbox **registrabile** | enqueue + drain manuale | `sync_events` |
| M15 | Riga import Excel con **errore** | file minimo locale | Import analysis |
| M16 | Riga import Excel **valida** | stesso file | Happy path |
| M17 | Export / reimport **idempotente** | round-trip senza duplicati funzionali | P84-08 |

Ogni elemento deve avere: **ID interno manifest**, **barcode/UUID inventati**, **owner test**, **ordine operazioni**, **esito atteso** (PASS/PARTIAL/BLOCKED), **evidenza privacy-safe** (conteggi soltanto).

### Formato minimo consigliato per ogni record manifest

Ogni record del manifest futuro dovrebbe essere scritto in modo tracciabile, senza dati reali:

| Campo | Regola |
|-------|--------|
| `manifest_id` | Prefisso stabile, es. `P84-M2-ANDROID-NEW-PRODUCT` |
| `platform_origin` | `android`, `ios`, `supabase_seed`, `excel_fixture` |
| `entity_type` | `product`, `supplier`, `category`, `product_price`, `sync_event`, `history`, `excel_row` |
| `business_key` | Barcode / nome / chiave sandbox inventata; mai barcode negozio reale |
| `operation_order` | Numero progressivo per riprodurre il caso |
| `expected_android` | Cosa deve vedere Android dopo sync/import/export |
| `expected_ios` | Cosa deve vedere iOS dopo sync/import/export |
| `expected_supabase` | Tabelle/righe attese in forma aggregata, senza dump payload |
| `expected_result` | `PASS`, `PARTIAL`, `BLOCKED`, `NOT RUN` |
| `privacy_note` | Conferma che il record è sandbox e non contiene dati reali |

Decisione planning: senza questo formato minimo, una futura execution P84 deve fermarsi in **BLOCKED**, come già successo in TASK-083 per manifest incompleto.

---

## Scenari P84 *(pianificati — NOT RUN)*

Per ogni scenario: stato iniziale **PLANNED** / **NOT RUN**; nessuna execution in TASK-084.

### P84-01 — Inventory schema parity read-only

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Tabella di mappatura campo-per-campo (documento) tra modelli Android, tabelle Supabase (clone), SwiftData iOS per inventory catalog + prezzi |
| Dati richiesti | Solo schema/metadati lettura locale |
| Direzione dati | N/A (read-only) |
| Check atteso | Elenco gap espliciti; nessuna supposizione silenziosa |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Schema clone non aggiornato rispetto remoto team |

### P84-02 — Android → Supabase → iOS: prodotto nuovo

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Verificare che prodotto creato su Android compaia dopo pull/apply (o equivalente) su iOS con stessi campi contrattuali |
| Dati richiesti | Manifest M2, M6, M7 |
| Direzione dati | Android → cloud → iOS |
| Check atteso | Presenza barcode; FK fornitore/categoria coerenti |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | RLS owner, baseline stale, guard prezzi/catalogo |

### P84-03 — iOS → Supabase → Android: prodotto nuovo

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Stesso di P84-02 in direzione inversa |
| Dati richiesti | Manifest M3 |
| Direzione dati | iOS → cloud → Android |
| Check atteso | Visibilità su Android dopo refresh/sync manuale Android |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Push iOS parziale; conflict policy |

### P84-04 — Android modifica prezzo → iOS vede storico

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Modifica prezzi lato Android; su iOS storico e current coerenti con TASK-080 |
| Dati richiesti | M8, M9, M10 |
| Direzione dati | Android → cloud → iOS |
| Check atteso | Righe `inventory_product_prices` + UI iOS **senza** doppioni |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | `effective_at` vs `updated_at` mismatch |

### P84-05 — iOS modifica prezzo → Android vede storico

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Inverso di P84-04 |
| Dati richiesti | M8, M9, M10 |
| Direzione dati | iOS → cloud → Android |
| Check atteso | `ProductPriceSummary` Android (o equivalente) allineato |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Dedupe/conflict Android side |

### P84-06 — Supplier / category parity

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | CRUD riferimenti su una piattaforma visibile dall’altra |
| Dati richiesti | M6, M7 |
| Direzione dati | Bidirezionale (due sotto-casi) |
| Check atteso | Integrità FK, assenza orfani |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Ordine push dipendente |

### P84-07 — Import Excel Android vs iOS: mapping e analysis

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Stesso file sandbox: conteggi righe valide/errori compatibili a livello **funzionale** |
| Dati richiesti | M15, M16 |
| Direzione dati | File locale per piattaforma → DB locale → opz. cloud |
| Check atteso | Stesso barcode valido accettato/rigettato analogamente |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Alias colonne divergenti |

### P84-08 — Export database Android vs iOS: struttura compatibile

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Export da iOS reimportabile su Android e viceversa *(se previsto dal prodotto)* o elenco gap |
| Dati richiesti | M17 |
| Direzione dati | Round-trip controllato |
| Check atteso | Idempotenza o elenco incompatibility documentato |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Formato diverso non documentato |

### P84-09 — Outbox / `sync_events` parity

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Stesso significato di dominio/eventType; drain non corrompe remote; idempotenza |
| Dati richiesti | M14 |
| Direzione dati | Locale → RPC → remoto |
| Check atteso | `client_event_id` stabile; limiti `changed_count` |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | PayloadValidation Android vs iOS |

### P84-10 — Conflict / timestamp / tombstone parity

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | M11, M12, M13 esercitati; policy TASK-082 rispettata su entrambe le piattaforme |
| Dati richiesti | Manifest conflitto controllato |
| Direzione dati | Multi-writer |
| Check atteso | Nessuna promessa “merged silenziosamente” senza evidenza |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Schema senza tombstone → follow-up backend |

### P84-11 — Scanner / manual entry parity

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Stessi esiti **dati** (non pixel) per creazione rapida articolo |
| Dati richiesti | Barcode sandbox |
| Direzione dati | UI locale → DB |
| Check atteso | Record equivalente post-sync |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Permessi camera iOS |

### P84-12 — History entries parity

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Allineare significato sessione inventario locale vs export/cloud se applicabile |
| Dati richiesti | Sessione sandbox |
| Direzione dati | Locale-centric |
| Check atteso | Documentare cosa è solo-locale vs condiviso |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | HistoryEntry solo SwiftData senza mirror cloud |

### P84-13 — UX parity senza copiare UI Android

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Checklist: stessi **messaggi di esito** utente (success/partial/blocked), non stesso layout |
| Dati richiesti | N/A |
| Direzione dati | N/A |
| Check atteso | Coerenza “cosa è successo” cross-platform |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Gergo residuo in una delle due app |

### P84-14 — Dataset medio performance parity

| Campo | Contenuto |
|-------|-----------|
| Obiettivo | Soglie tempo percepito import/sync su volume intermedio |
| Dati richiesti | Dataset medio sandbox *(non negozio reale)* |
| Direzione dati | Misura |
| Check atteso | PARTIAL_EXPECTED ammesso se documentato |
| Stato iniziale | PLANNED — NOT RUN |
| Blocchi possibili | Da deferire parzialmente a **TASK-085** |

---

## Ordine consigliato per futura execution P84

Questa è solo una proposta di sequenza, non autorizza execution. Serve a evitare smoke casuali o troppo grandi.

| Fase | Scenari | Scopo | Gate per procedere |
|------|---------|-------|--------------------|
| P84-A | P84-01 | Schema/model parity read-only | Nessun campo critico non mappato o gap documentato |
| P84-B | Manifest M1…M17 | Preparare dataset sandbox completo | Manifest approvato, privacy-safe, senza dati negozio |
| P84-C | P84-02, P84-03, P84-06 | Ciclo base product/supplier/category bidirezionale | PASS/PARTIAL spiegato, nessun duplicato critico |
| P84-D | P84-04, P84-05 | Prezzi e storico `ProductPrice` bidirezionale | Nessun doppio storico, `effective_at` coerente |
| P84-E | P84-09, P84-10 | Outbox, conflitti, timestamp, tombstone | Nessun write non confermato, policy chiara |
| P84-F | P84-07, P84-08, P84-11, P84-12 | Import/export/manual entry/history | Gap documentati, nessun claim falso di parità |
| P84-G | P84-13, P84-14 | UX parity e dataset medio | Solo dopo baseline funzionale sandbox |

Regola: se P84-A o P84-B sono **BLOCKED**, non passare ai cicli bidirezionali. Aprire follow-up schema/manifest invece di forzare test manuali.

### Stop conditions future

La futura execution P84 deve fermarsi se:

- il manifest M1…M17 è incompleto o contiene dati reali;
- schema Android/iOS/Supabase non è mappabile senza inventare colonne;
- owner/session/RLS non sono chiari;
- una piattaforma richiede cleanup/reset/truncate/delete per proseguire;
- ProductPrice genera doppio storico non spiegato;
- un conflitto viene risolto silenziosamente senza summary utente;
- Android e iOS divergono ma il piano non riesce a stabilire se è gap funzionale, UX accettabile o problema backend;
- si rischia di dichiarare parità solo perché uno scenario non è stato eseguito.

---

## Decisioni planning D84

| ID | Decisione |
|----|-----------|
| D84-01 | **iOS** resta **target principale** di modifiche future. |
| D84-02 | **Android** è **riferimento funzionale**, non sorgente da copiare riga-per-riga. |
| D84-03 | **Supabase** è la **fonte di verità condivisa** per dati cross-platform. |
| D84-04 | **Nessun dato reale negozio** nel primo smoke di parità. |
| D84-05 | **Nessuna parità** “completa” dichiarata **senza manifest + evidenze scenario**. |
| D84-06 | **UX iOS** può restare **diversa** da Android se più nativa e **più chiara** per l’utente. |
| D84-07 | In dubbio: **sicurezza dati > velocità**. |
| D84-08 | Se lo **schema Supabase** non supporta un caso Android stabile: **follow-up backend separato** — **vietato** inventare colonne nel planning iOS. |
| D84-09 | Se **iOS** manca una feature Android stabile: registrare **gap** e proporre **task futuro** — non scope creep dentro TASK-084 execution (quando autorizzata). |
| D84-10 | Il **planning TASK-084** non implementa patch né promuove TASK-085. |
| D84-11 | La parità è misurata per **esito dati + messaggio utente**, non per layout identico Android/iOS. |
| D84-12 | Il manifest M1…M17 è gate obbligatorio prima di qualunque futura execution runtime. |
| D84-13 | Gli scenari P84 devono riportare anche **NOT RUN** esplicito; vietato omettere scenari non eseguiti. |
| D84-14 | Se una feature Android stabile manca su iOS, il planning deve registrare gap + proposta task futuro, non implementarla direttamente. |
| D84-15 | Se una differenza iOS è migliore come UX nativa e non altera i dati, può essere accettata come parità UX. |
| D84-16 | I test futuri devono partire da schema/model parity read-only prima di qualunque write o smoke bidirezionale. |
| D84-17 | Ogni riga della matrice deve ricevere una classificazione gap esplicita prima di qualsiasi claim di parità. |
| D84-18 | Le differenze UX accettate devono essere marcate come `ACCEPTED_NATIVE_IOS`, non lasciate come ambiguità. |
| D84-19 | Il manifest sandbox deve usare prefissi riconoscibili `P84SANDBOX*` o equivalenti per evitare confusione con dati reali. |
| D84-20 | Se il primo ciclo P84-A/P84-B è bloccato, la prossima azione è follow-up schema/manifest, non execution manuale ad hoc. |
| D84-21 | Le aree P0/P1 devono usare un field mapping Android ↔ Supabase ↔ iOS prima di essere marcate MATCH. |
| D84-22 | Le regole di normalizzazione del manifest devono essere decise prima della futura execution, non durante lo smoke. |
| D84-23 | Se una differenza dipende da normalizzazione non decisa, lo scenario resta PARTIAL/BLOCKED_MANIFEST. |
| D84-24 | Ogni gap deve avere un routing esplicito: iOS, Android, Supabase/backend, manifest, evidenza o out-of-scope. |
| D84-25 | TASK-084 non deve trasformare automaticamente un gap in patch; prima serve review e task separato. |
| D84-26 | Una differenza UX accettata come nativa iOS non deve generare lavoro solo per “somigliare ad Android”. |

---


## Rischi

| Rischio | Mitigazione (planning) |
|---------|-------------------------|
| Mismatch schema Android / iOS / Supabase | P84-01 obbligatorio prima di smoke; clone Supabase come riferimento |
| ProductPrice current/previous disallineato | Scenari P84-04/05 + vincoli tabella prezzi |
| Duplicati barcode | M11 + policy dedupe documentata |
| Owner / sessione / RLS | Preflight auth identico a TASK-082; account sandbox dedicato |
| `effective_at` vs `updated_at` | Decisioni TASK-080/082 rilette in matrice |
| Outbox non riproducibile | Manifest M14; vietato inject arbitrario non conforme RLS |
| Dataset manifest incompleto | **Lezione TASK-083**: checklist M1…M17 prima di EXECUTION |
| UX iOS troppo Android-like | D84-06 — valutare solo chiarezza esito |
| Performance dataset grande | P84-14 / TASK-085 |
| Claim falso di parità | Obbligo NOT RUN / BLOCKED espliciti; nessun PASS implicito |

---

## Evidenze future privacy-safe

Per una futura execution P84, ogni scenario deve produrre evidenze aggregate e riproducibili:

| Tipo evidenza | Esempio ammesso | Vietato |
|---------------|-----------------|---------|
| Conteggi | `1 prodotto Android creato → 1 prodotto visibile iOS` | Lista barcode reali o dump completo prodotti |
| Screenshot UI | Summary con dati sandbox oscurati | Token, email, owner id, dati negozio |
| Schema mapping | Tabella campo Android ↔ Supabase ↔ iOS | Segreti o URL con query sensibili |
| Import/export | Nome fixture sandbox + conteggi righe | File reale negozio allegato al report |
| ProductPrice | Numero righe storico e stato duplicate/skip | Prezzi/listini reali completi |
| Outbox | Numero attività registrate / in attesa / bloccate | Payload JSON completo `sync_events` |

Convenzione suggerita:

```text
TASK-084_P84-xx_<AndroidToIOS|IOSToAndroid|ReadOnly>_<YYYY-MM-DD>_<PASS|PARTIAL|BLOCKED|NOT-RUN>
```

Ogni scenario non eseguito deve essere marcato **NOT RUN** con motivo.

### Template mini-report scenario P84

Ogni futura execution/review scenario dovrebbe usare un template compatto:

```markdown
### P84-xx — Titolo

- Run ID:
- Direzione: Android → Supabase → iOS / iOS → Supabase → Android / ReadOnly
- Manifest usato: Mx, My, ...
- Stato: PASS / PARTIAL / BLOCKED / FAIL / NOT RUN
- Classificazione gap: MATCH / ACCEPTED_NATIVE_IOS / PARTIAL / MISSING_IOS / MISSING_ANDROID / SCHEMA_GAP / BLOCKED_MANIFEST / OUT_OF_SCOPE_TASK_084
- Conteggi aggregati:
- Cosa vede Android:
- Cosa vede iOS:
- Cosa risulta su Supabase:
- Differenze UX accettate:
- Follow-up richiesto:
- Evidenze privacy-safe:
```

Il template serve a impedire report vaghi tipo “sembra funzionare”: ogni scenario deve dire chiaramente cosa è stato visto su Android, iOS e Supabase.

### Report gap summary futuro

Al termine di una futura review/execution P84, il riepilogo deve aggregare i gap così:

| Categoria | Conteggio | Azione consigliata |
|-----------|-----------|--------------------|
| MATCH | n | Può contribuire alla parità dichiarata |
| ACCEPTED_NATIVE_IOS | n | Accettato come UX iOS nativa, nessuna patch obbligatoria |
| PARTIAL | n | Richiede evidenza aggiuntiva o scenario mirato |
| MISSING_IOS | n | Candidato task iOS futuro |
| MISSING_ANDROID | n | Candidato task Android futuro, non dentro iOS TASK-084 |
| SCHEMA_GAP | n | Candidato task Supabase/backend separato |
| BLOCKED_MANIFEST | n | Completare manifest prima di retry |
| OUT_OF_SCOPE_TASK_084 | n | Spostare a TASK-085 o task dedicato |

Questa tabella impedisce di trasformare una lista lunga di osservazioni in un generico “parità quasi completa”.

### Routing follow-up gap

Quando una futura review trova un gap, non deve trasformarlo automaticamente in patch dentro TASK-084. Usare invece questa regola di routing:

| Gap rilevato | Azione corretta |
|--------------|-----------------|
| `MISSING_IOS` su funzione Android stabile e utile | Proporre task iOS separato con perimetro piccolo e file target iOS |
| `MISSING_ANDROID` | Documentare come gap Android/futuro lavoro cross-platform, non modificarlo da repo iOS |
| `SCHEMA_GAP` | Proporre task Supabase/backend separato, con lettura schema prima di qualunque codice |
| `BLOCKED_MANIFEST` | Completare manifest sandbox, non fare smoke manuale ad hoc |
| `PARTIAL` per evidenze insufficienti | Aggiungere scenario/evidenza mirata, non dichiarare PASS |
| `ACCEPTED_NATIVE_IOS` | Nessuna patch obbligatoria; registrare la decisione UX |
| `OUT_OF_SCOPE_TASK_084` | Spostare a TASK-085 o task dedicato, senza aprirlo automaticamente |

Decisione: TASK-084 planning serve a classificare e instradare correttamente i gap. Non deve diventare un contenitore dove implementare qualunque differenza trovata.

---

## Planning (Claude) — analisi, approccio, file coinvolti

### Analisi

L’iOS ha completato una **cutline Release** per sync mutativa manuale (TASK-078…082) e una **chiusura documentale** TASK-083 senza smoke runtime per **manifest incompleto**. La parità Android ↔ iOS non è un’estensione banale: richiede **stesso contratto dati** su Supabase, **stessi significati** per conflitto/storico/outbox, e **manifest sandbox** che copra prezzi, duplicati e attività come **condizione necessaria** (non sufficiente) per qualsiasi futura campagna di smoke.

### Approccio proposto (documentale)

1. Completare **review planning** su questa bozza (utente / reviewer).
2. Leggere in modo mirato i file Android elencati e il clone Supabase **solo lettura** per raffinare la matrice (senza SQL applicato).
3. Congelare **manifest M1…M17** con valori fittizi approvati dal team.
4. Solo dopo handoff **EXECUTION** separato (non autorizzato da questo file da solo): eseguire scenari P84 in ordine P84-01 → dipendenze, con evidenze privacy-safe.

### File coinvolti *(futura execution / review — elenco indicativo)*

- iOS: modelli sync, `Supabase*` servizi, `DatabaseView`, import/export, `GeneratedView` / `HistoryEntry`
- Android: file elencati in § Fonti
- Supabase: migrazioni in `MerchandiseControlSupabase`
- Tracking: `docs/MASTER-PLAN.md`, questo file

---

## Criteri di accettazione *(contratto fase PLANNING)*

- [ ] Matrice parità (25 righe minime) presente e significativa.
- [ ] Manifest sandbox M1…M17 definito con intento privacy-safe.
- [ ] Scenari P84-01…P84-14 descritti con obiettivo/dati/direzione/check/NOT RUN.
- [ ] Decisioni D84 presenti.
- [ ] Rischi principali elencati.
- [ ] Handoff chiarisce **NON READY FOR EXECUTION** fino a review esplicita.
- [ ] Nessuna modifica codice e nessun write Supabase imputabile a TASK-084 planning.
- [ ] Principi UX/UI parity definiti: parità di esito, non copia layout Android.
- [ ] Formato manifest minimo definito per evitare una nuova chiusura BLOCKED come TASK-083.
- [ ] Stop conditions future documentate.
- [ ] Evidenze privacy-safe future definite.
- [ ] Tassonomia gap definita e applicabile alla matrice.
- [ ] Regola decisionale UX definita per distinguere parità nativa iOS da vero gap funzionale.
- [ ] Template mini-report scenario P84 definito.
- [ ] Template field mapping Android ↔ Supabase ↔ iOS definito per aree P0/P1.
- [ ] Regole di normalizzazione manifest elencate prima di ogni execution futura.
- [ ] Report gap summary futuro definito.
- [ ] Routing follow-up gap definito per evitare patch automatiche dentro TASK-084.
- [ ] Chiarito che `ACCEPTED_NATIVE_IOS` non richiede lavoro solo per somiglianza visiva ad Android.

---

## Check finali planning

| Check | Stato | Note |
|-------|-------|------|
| `git diff --check` | Da eseguire in review/commit | Solo markdown: consigliato prima di chiudere planning review |
| Build / `xcodebuild` | **NON obbligatorio** | Escluso dal perimetro |
| Test runtime | **NON eseguito** | Escluso |
| Write Supabase | **NON eseguito** | Escluso |
| Codice Swift/Kotlin/SQL modificato | **NON eseguito** | Escluso |
| Review coerenza markdown | Da eseguire in review | Controllare che D84, P84, M1…M17 e tassonomia gap siano coerenti tra loro |

---

## Final Planning Review — criteri per non espandere oltre

Il piano TASK-084 è sufficientemente completo per una review documentale quando sono presenti:

- matrice di parità con 25 aree;
- tassonomia gap;
- template field mapping per aree P0/P1;
- manifest M1…M17 con formato record;
- regole di normalizzazione da decidere;
- scenari P84-01…P84-14;
- ordine consigliato futura execution;
- stop conditions;
- evidenze privacy-safe;
- mini-report scenario e gap summary.

Da questo punto, ulteriori richieste dovrebbero essere classificate come:

1. review documentale del piano;
2. raffinamento repo-grounded read-only su Android/Supabase/iOS;
3. execution futura con override esplicito;
4. follow-up separato per iOS, Android, Supabase/backend o TASK-085.

Non aggiungere nuove sezioni generiche se non riducono un'ambiguità concreta della matrice, del manifest o degli scenari P84.

### Checklist di chiusura planning review

Prima di chiudere la review planning o autorizzare qualunque futura execution, il reviewer deve confermare:

- [ ] Nessuna riga della matrice viene trattata come MATCH senza field mapping o motivazione.
- [ ] Ogni differenza UX è classificata come gap reale oppure `ACCEPTED_NATIVE_IOS`.
- [ ] Ogni gap ha un routing: iOS / Android / Supabase-backend / manifest / evidenza / TASK-085.
- [ ] Il manifest M1…M17 è considerato gate, non suggerimento opzionale.
- [ ] Nessun dato negozio reale è richiesto per il primo ciclo P84.
- [ ] Nessuna sezione del piano autorizza execution, patch Swift/Kotlin/SQL o write Supabase.

---

## Execution

### Execution start

- **Timestamp:** 2026-05-08 21:06 -0400
- **Branch iOS:** `main`
- **Commit iOS:** `7e087d5`
- **Working tree iOS:** dirty preesistente/in corso tracking: `M docs/MASTER-PLAN.md`; `?? docs/TASKS/TASK-084-android-ios-cross-platform-parity.md`
- **Xcode:** `Xcode 26.4.1` / `Build version 17E202`
- **Android repo commit:** `865b537`
- **Android repo status:** dirty: `M gradle/libs.versions.toml`
- **Supabase local repo status:** ⚠️ NON ESEGUIBILE come git status: `/Users/minxiang/Desktop/MerchandiseControlSupabase` è leggibile ma non è una working tree git (`fatal: not a git repository`)
- **Scope autorizzato ora:** P84-A schema/model parity read-only; P84-B manifest sandbox M1…M17 solo documentale; P84-C solo schede future P84-02/P84-03/P84-06 in stato PLANNED / NOT RUN.
- **Anti-scope confermato:** nessun runtime iOS/Android; nessun write Supabase; nessun drain outbox live; nessun push catalogo live; nessun ProductPrice live; nessun dataset medio o negozio reale; nessuna modifica Swift/Kotlin/SQL/backend/`project.pbxproj`/`Localizable.strings`; nessuna apertura TASK-085; nessuna dichiarazione DONE.

### Obiettivo compreso

Eseguire TASK-084 in modo progressivo e verificabile con una prima execution esclusivamente documentale/read-only: leggere repo iOS, Android e Supabase locale, produrre mapping Android ↔ Supabase ↔ iOS, classificare gap con la tassonomia D84, preparare un manifest sandbox privacy-safe M1…M17 senza dati reali e predisporre solo schede future P84-C senza runtime o write.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-084-android-ios-cross-platform-parity.md`
- `docs/TASKS/TASK-083-supabase-end-to-end-release-smoke-ios.md`

### Piano minimo

1. Confermare tracking e baseline execution.
2. Leggere in sola lettura file iOS/Android/Supabase rilevanti per P84-A.
3. Compilare mapping P0/P1 e classificare gap senza usare MATCH quando manca una delle tre fonti.
4. Preparare manifest M1…M17 documentale e regole di normalizzazione.
5. Preparare P84-C solo come schede PLANNED / NOT RUN.
6. Eseguire solo `git diff --check` e `git status --short`; non eseguire build/runtime/test.

### Letture read-only repo-grounded

| Fonte | File / area letta | Evidenza |
|-------|--------------------|----------|
| Tracking | `docs/MASTER-PLAN.md`, TASK-084, TASK-083 | TASK-084 era ACTIVE / PLANNING; TASK-083 DONE / CHIUSURA; TASK-085 resta TODO / Planning e non e' stato aperto. |
| Task collegati | TASK-075, TASK-078, TASK-079, TASK-080, TASK-081, TASK-082 | Tutti letti come contesto DONE / Chiusura per smoke, pull/push catalogo, ProductPrice, outbox, conflitti/timestamp. |
| iOS modelli | `Models.swift`, `HistoryEntry.swift`, `SupabaseInventoryDTOs.swift`, `SyncEventOutboxEntry.swift`, `SyncEventRecording.swift`, `SupabaseSyncEventDTOs.swift`, `SyncEventRPCRequestMapper.swift` | Campi SwiftData/DTO e contratto outbox letti in sola lettura. |
| iOS sync | `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift`, `SupabasePullApplyService.swift`, `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `OptionsView.swift` | Mapping pull/apply/push, ProductPrice, review sheet e activity registration verificati staticamente. |
| iOS import/export/UI | `ProductImportCore.swift`, `ProductImportViewModel.swift`, `ExcelSessionViewModel.swift`, `ImportAnalysisView.swift`, `DatabaseView.swift`, `GeneratedView.swift`, `InventoryXLSXExporter.swift` | Header alias, dedupe import, export Products/Full DB/PriceHistory, HistoryEntry e manual entry verificati staticamente. |
| Android modelli | `Product.kt`, `Supplier.kt`, `Category.kt`, `ProductPrice.kt`, `ProductWithDetails.kt`, `ProductPriceSummary.kt`, `HistoryEntry.kt`, `AppDatabase.kt`, `ProductRemoteRef.kt`, `SupplierRemoteRef.kt`, `CategoryRemoteRef.kt`, `ProductPriceRemoteRef.kt` | Room schema locale, remote refs, current/previous price e version 15/outbox letti staticamente. |
| Android sync/UI/import/export | `InventoryCatalogRemoteRows.kt`, `SupabaseCatalogRemoteDataSource.kt`, `SupabaseProductPriceRemoteDataSource.kt`, `SyncEventModels.kt`, `SupabaseSyncEventRemoteDataSource.kt`, `InventoryRepository.kt`, `ExcelUtils.kt`, `ImportAnalysis.kt`, `DatabaseExportWriter.kt`, `DatabaseViewModel.kt`, `DatabaseScreen.kt`, `GeneratedScreen.kt`, `CatalogSyncViewModel.kt`, `OptionsScreen.kt` | Contratti Supabase, import/export, quick/full sync, sync_events/outbox e UI funzionale verificati staticamente. |
| Supabase locale | `20260417120000_task013_inventory_catalog_rls.sql`, `20260418200000_task019_inventory_catalog_tombstone.sql`, `20260417200000_task016_inventory_product_prices.sql`, `20260421120000_task038_restrict_authenticated_delete_inventory.sql`, `20260424021936_task045_sync_events.sql`, `sql/005_history_entries.sql` | Schema/RLS/RPC letto in sola lettura; path non e' repo git ma e' leggibile. |

### P84-A — Schema/model parity read-only

| Area | Android model/file | Supabase table/columns | iOS model/file | Mapping | Gap status | Note |
|------|--------------------|------------------------|----------------|---------|------------|------|
| Product | `Product.kt`, `ProductWithDetails.kt`, `InventoryProductRow`, `ProductRemoteRef` | `inventory_products`: `id`, `owner_user_id`, `barcode`, `item_number`, `product_name`, `second_product_name`, `purchase_price`, `retail_price`, `supplier_id`, `category_id`, `stock_quantity`, `updated_at`, `deleted_at` | `Product` in `Models.swift`, `RemoteInventoryProductRow`, pull/push services | Core catalog fields map; Android stores remote identity in bridge, iOS inline `remoteID`; Supabase authoritative owner/remote id. | PARTIAL | Android remote row letto non decodifica `updated_at`; iOS lo usa come `remoteUpdatedAt`. Runtime NOT RUN. |
| Supplier | `Supplier.kt`, `SupplierRemoteRef`, `InventorySupplierRow` | `inventory_suppliers`: `id`, `owner_user_id`, `name`, `updated_at`, `deleted_at`, unique lower active | `Supplier`, `RemoteInventorySupplierRow` | Name + remote id map; both clients trim names on apply/import. | PARTIAL | Android bridge tracks fingerprint/applied time; iOS stores `remoteUpdatedAt`; case/accent policy not identical. |
| Category | `Category.kt`, `CategoryRemoteRef`, `InventoryCategoryRow` | `inventory_categories`: `id`, `owner_user_id`, `name`, `updated_at`, `deleted_at`, unique lower active | `ProductCategory`, `RemoteInventoryCategoryRow` | Name + remote id map; FK product links map through remote ids. | PARTIAL | Android Room `NOCASE`; Supabase lower; iOS SwiftData unique case behavior not proven equivalent. |
| ProductPrice / storico prezzi | `ProductPrice.kt`, `ProductPriceRemoteRef`, `InventoryProductPriceRow`, `SupabaseProductPriceRemoteDataSource` | `inventory_product_prices`: `id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `source`, `note`, `created_at`, unique owner/product/type/effective | `ProductPrice`, `RemoteInventoryProductPriceRow`, `SupabaseProductPriceApplyService`, `SupabaseProductPriceManualPushService` | Type/price/effective/source/note map; parent product is remote id; dedupe by logical key. | PARTIAL | iOS does not persist remote row id for `ProductPrice`; Android does via bridge. iOS push uses deterministic id; Android uses existing/random id. |
| Current price / previous price | `Product.purchasePrice`, `retailPrice`, `oldPurchasePrice`, `oldRetailPrice`, `ProductPriceSummary` last/prev | Current snapshot on `inventory_products`; history in `inventory_product_prices`; no `previous_*` columns | `Product.purchasePrice`, `retailPrice`, `ProductPrice` history, `ProductPriceHistoryView` | Current price snapshot exists on all; previous price is derived or local-only, not a Supabase column. | PARTIAL | Android has explicit old fields and summary view; iOS export/model lacks `oldPurchasePrice`/`oldRetailPrice` fields. |
| sync_events / outbox | `SyncEventModels.kt`, `SupabaseSyncEventRemoteDataSource.kt`, Room `sync_event_outbox` | `sync_events`, RPC `record_sync_event`, RLS owner, domains `catalog`/`prices`, events `*_changed`/`*_tombstone`, `changed_count`, `client_event_id` | `SyncEventOutboxEntry`, `SyncEventRecording`, `SyncEventRPCRequestMapper`, `SupabaseSyncEventDTOs` | Contract fields and allowed domain/event types align across Android, Supabase and iOS. | MATCH | MATCH only for static schema/RPC/model contract; drain/runtime idempotence is NOT RUN. |
| Import Excel | `ExcelUtils.kt`, `ImportAnalysis.kt`, `DatabaseViewModel.kt` | N/A direct; later sync uses catalog/ProductPrice tables | `ExcelSessionViewModel.swift`, `ProductImportCore.swift`, `DatabaseView.swift` | Both recognize canonical product fields, trim barcode, aggregate duplicate barcode with last row semantics, create suppliers/categories. | PARTIAL | Android validation is stricter: product name/second name required, retail price positive, discount support, accent-insensitive relation matching. |
| Export database | `DatabaseExportWriter.kt`, `DatabaseViewModel.kt` | N/A direct; export is local file interchange | `DatabaseView.swift`, `InventoryXLSXExporter.swift` | Both support Products/Suppliers/Categories/PriceHistory sheets conceptually. | PARTIAL | Android exports old price columns and supplier/category ids; iOS full export omits old price columns and supplier/category ids. Round-trip compatibility not proven. |
| HistoryEntry | `HistoryEntry.kt`, `HistoryEntryRemoteRef`, `GeneratedScreen.kt` | `sql/005_history_entries.sql` is draft only, no definitive public table/migration | `HistoryEntry.swift`, `GeneratedView.swift` | Local snapshot concepts align: id/display/timestamp/data/editable/complete/supplier/category/totals/status/export/manual. | SCHEMA_GAP | Shared Supabase contract for history entries is intentionally undecided. Do not claim cloud parity. |
| Conflict/timestamp/tombstone | `PendingCatalogTombstone`, remote refs, fingerprint, `deletedAt`, sync events | Catalog `updated_at` + `deleted_at` partial unique; ProductPrice lacks `updated_at` and `deleted_at`; RPC tombstone event types | iOS `remoteUpdatedAt`, `remoteDeletedAt`, baseline/preview/apply guards, ProductPrice logical-key conflict handling | Catalog tombstone exists; price conflicts use logical keys; sync_events can signal tombstone events. | PARTIAL | ProductPrice tombstone is not a table column; Android catalog row model omits `updated_at`; policies need scenario evidence. |

### Field mapping P0/P1 — Product

| Campo | Android | Supabase | iOS | Regola parità | Gap status |
|-------|---------|----------|-----|---------------|------------|
| Identità prodotto | `Product.id` locale + `ProductRemoteRef.remoteId`; business `barcode` | `inventory_products.id` + `owner_user_id` + active unique `(owner_user_id, barcode)` | `Product.remoteID` + `Product.barcode` | Remote id identifica riga cloud; barcode identifica articolo sandbox attivo. | PARTIAL |
| Barcode | `Product.barcode`; trim inbound in repository/import | `barcode text not null`; unique active; zero iniziali preservati | `Product.barcode`; `normalizedBarcode` = trim non-empty | Trim boundary; non lower-case; non convertire in numero. | MATCH |
| Nome prodotto | `productName` nullable, import Android richiede almeno uno tra nome e secondo nome | `product_name` nullable | `productName` nullable | Test sandbox deve dichiarare valore atteso esplicito. | PARTIAL |
| Secondo nome | `secondProductName` nullable | `second_product_name` nullable | `secondProductName` nullable | Campo opzionale, preservato se presente. | MATCH |
| Supplier | `supplierId` locale FK + `SupplierRemoteRef.remoteId` | `supplier_id` FK nullable | `supplier?.remoteID` | Nessun orfano: supplier deve esistere prima del prodotto o essere risolto nel pull. | PARTIAL |
| Category | `categoryId` locale FK + `CategoryRemoteRef.remoteId` | `category_id` FK nullable | `category?.remoteID` | Nessun orfano: category deve esistere prima del prodotto o essere risolta nel pull. | PARTIAL |
| Purchase price | `purchasePrice`; import round3 | `purchase_price double precision` | `purchasePrice Double?`; sync fingerprint scale 6, ProductPrice scale 3 | Current snapshot deve coincidere entro tolleranza documentata. | PARTIAL |
| Retail price | `retailPrice`; Android import richiede positivo per nuovi/esistenti se fornito | `retail_price double precision` | `retailPrice Double?` | Current snapshot deve coincidere; validazione iOS import non equivalente ad Android. | PARTIAL |
| Current / previous price | Current da `ProductPriceSummary.last*` fallback product; previous da `prev*` o `old*` | Current snapshot + storico; nessun previous column | Current da `Product`/history; previous solo derivabile dalla history, non campo prodotto | Non dichiarare parity previous senza scenario M8-M10. | PARTIAL |
| `updated_at` | Non presente in `InventoryProductRow`; bridge usa fingerprint/applied time | `updated_at timestamptz not null` | `remoteUpdatedAt Date?` | iOS usa timestamp remoto; Android non lo mappa come campo business nel row letto. | MISSING_ANDROID |
| `deleted_at` / tombstone | `deletedAt` in row + `PendingCatalogTombstone` | `deleted_at timestamptz`; partial unique active | `remoteDeletedAt Date?` | Catalog tombstone supportato; no cleanup fisico nei test. | MATCH |
| `owner_user_id` | `InventoryProductRow.ownerUserId` | `owner_user_id uuid` RLS | `RemoteInventoryProductRow.ownerUserID` | Tutte le righe sandbox devono appartenere allo stesso owner test. | MATCH |

### Field mapping P0/P1 — Supplier / Category

| Campo | Android | Supabase | iOS | Regola parità | Gap status |
|-------|---------|----------|-----|---------------|------------|
| Identità supplier | `Supplier.id` + `SupplierRemoteRef.remoteId` | `inventory_suppliers.id` | `Supplier.remoteID` | Remote id autorevole; name business key secondaria. | PARTIAL |
| Supplier name | `Supplier.name`, unique Room; import trim, relation key accent-insensitive | `name`, unique lower active | `Supplier.name`, unique SwiftData; import trim | Matching per name normalizzato da decidere per accenti/case. | PARTIAL |
| Identità category | `Category.id` + `CategoryRemoteRef.remoteId` | `inventory_categories.id` | `ProductCategory.remoteID` | Remote id autorevole; name business key secondaria. | PARTIAL |
| Category name | `Category.name` NOCASE + relation key accent-insensitive | `name`, unique lower active | `ProductCategory.name`, unique SwiftData | Matching case/accent non provato equivalente. | PARTIAL |
| `updated_at` | Non decodificato nei row supplier/category Android | `updated_at timestamptz` | `remoteUpdatedAt Date?` | Timestamp catalogo utile per stale/conflict iOS; gap Android. | MISSING_ANDROID |
| `deleted_at` | `deletedAt` in row + tombstone apply | `deleted_at timestamptz` | `remoteDeletedAt Date?` | Supporto catalog tombstone su entrambe le app, runtime NOT RUN. | MATCH |
| `owner_user_id` | Row remote `ownerUserId` | RLS owner | Row iOS `ownerUserID` | Owner test deve essere identico. | MATCH |

### Field mapping P0/P1 — ProductPrice / sync_events

| Campo | Android | Supabase | iOS | Regola parità | Gap status |
|-------|---------|----------|-----|---------------|------------|
| Identità ProductPrice | `ProductPrice.id` locale + `ProductPriceRemoteRef.remoteId` | `inventory_product_prices.id uuid` | `ProductPrice` senza `remoteID` persistito | Remote row id non e' simmetrico; dedupe logico deve bastare o diventare follow-up. | MISSING_IOS |
| Parent product | `productId` locale + `productRemoteId` per push | `product_id uuid` FK | `product?.remoteID` | Product deve avere remote id prima di push/prezzo. | MATCH |
| Type | `PURCHASE` / `RETAIL` in Room e remote rows | check `PURCHASE`, `RETAIL` | local enum `purchase`/`retail`, push uppercased | Normalizzare case; manifest usa valori espliciti PURCHASE/RETAIL lato cloud. | MATCH |
| Price | `Double`, Android import round3 | `double precision not null` | `Double`, canonical scale 3 for ProductPrice apply/push | Prezzi sandbox simbolici interi 101/202/303 evitano arrotondamenti ambigui. | MATCH |
| `effective_at` | `effectiveAt String` formato `yyyy-MM-dd HH:mm:ss` | `effective_at text not null` | `effectiveAt Date`, canonical UTC `yyyy-MM-dd HH:mm:ss` | Timestamp manifest UTC esplicito, non `now`. | MATCH |
| `created_at` | `createdAt String`, default `effectiveAt` | `created_at text not null` | `createdAt Date`, canonical UTC | Se non testato, usare uguale a `effective_at`. | MATCH |
| ProductPrice `updated_at` | Non presente | Non presente | Non presente | Non usare per ordering prezzi; usare `effective_at`. | SCHEMA_GAP |
| ProductPrice `deleted_at` / tombstone | Event type `prices_tombstone`, no table field | Non presente in tabella prezzi | Event type supportato, no table field | Delete prezzo non verificabile come tombstone tabellare. | SCHEMA_GAP |
| sync event domain | `SyncEventDomains.CATALOG/PRICES` | `domain in ('catalog','prices')` | RPC mapper supporta `catalog`/`prices` | Domain deve matchare entity type. | MATCH |
| sync event eventType | `catalog_changed`, `prices_changed`, `catalog_tombstone`, `prices_tombstone` | same check constraint/RPC validation | same mapper validation | Event type coerente con domain. | MATCH |
| `client_event_id` | Outbox unique owner/client id; RPC param optional | unique partial `(owner_user_id, client_event_id)` | required locally for `SyncEventRecordRequest`; RPC param | Manifest deve dichiarare deterministic client id per M14. | MATCH |
| `changed_count` | Int, chunked/compacted; outbox stores | check/RPC range 0...1000 | validator range 0...1000 | Conteggi aggregati, mai payload reale. | MATCH |

### P84-B — Manifest sandbox M1…M17

Manifest documentale completo per il primo ciclo; **stato runtime: NOT RUN** per tutte le righe. Nessun dato e' stato creato su iOS, Android o Supabase.

| Manifest ID | Platform origin | Entity type | Business key sandbox | Operation order | Expected Android | Expected iOS | Expected Supabase | Expected result | Privacy note |
|-------------|-----------------|-------------|----------------------|-----------------|------------------|--------------|-------------------|-----------------|--------------|
| M1 | supabase_seed | product | `P84SANDBOX0001` / `P84 Sandbox Product 01` | 01 seed read-only baseline, no mutation | 1 prodotto visibile/invariato dopo sync futura | 1 prodotto visibile/invariato dopo pull futura | 1 active product, supplier/category FK sandbox, no new price row | NOT RUN | Sandbox only, no real store data |
| M2 | android | product | `P84SANDBOX0002` / `P84 Sandbox Product 02 Android` | 02 create Android, future push/sync | Nuovo prodotto locale Android con supplier/category M6/M7 | Dopo future pull, prodotto presente con stessi campi P0 | 1 active product con barcode M2 e owner test | NOT RUN | Sandbox barcode invented |
| M3 | ios | product | `P84SANDBOX0003` / `P84 Sandbox Product 03 iOS` | 03 create iOS, future push | Dopo future sync Android, prodotto presente | Nuovo prodotto locale iOS con supplier/category M6/M7 | 1 active product con barcode M3 e owner test | NOT RUN | Sandbox barcode invented |
| M4 | android | product_update | `P84SANDBOX0004` / name update `P84 Sandbox Product 04 Android Updated` | 04 seed then Android update timestamp `2026-05-08 21:20:00 UTC` | Android mostra nome aggiornato | iOS futura pull mostra nome aggiornato o blocco conflitto esplicito | `product_name` updated, `updated_at` advances | NOT RUN | Uses fake name/timestamp |
| M5 | ios | product_update | `P84SANDBOX0005` / name update `P84 Sandbox Product 05 iOS Updated` | 05 seed then iOS update timestamp `2026-05-08 21:25:00 UTC` | Android futura sync mostra nome aggiornato o blocco conflitto esplicito | iOS mostra nome aggiornato | `product_name` updated, `updated_at` advances | NOT RUN | Uses fake name/timestamp |
| M6 | android_or_ios | supplier | `P84 Sandbox Supplier` | 06 create before products M2/M3 | Supplier exists and links products | Supplier exists and links products | 1 active `inventory_suppliers` row | NOT RUN | Generic supplier name |
| M7 | android_or_ios | category | `P84 Sandbox Category` | 07 create before products M2/M3 | Category exists and links products | Category exists and links products | 1 active `inventory_categories` row | NOT RUN | Generic category name |
| M8 | android | product_price_purchase | `P84SANDBOX0008` purchase `101` then `202` | 08 change purchase at `2026-05-08 21:30:00 UTC` | Current purchase = 202, previous = 101 if UI exposes | Current purchase/history equivalent or PARTIAL explained | Product snapshot purchase 202; ProductPrice row effective_at fixed | NOT RUN | Symbolic prices only |
| M9 | ios | product_price_retail | `P84SANDBOX0009` retail `202` then `303` | 09 change retail at `2026-05-08 21:35:00 UTC` | Current retail = 303, previous = 202 if UI exposes | Current retail/history equivalent or PARTIAL explained | Product snapshot retail 303; ProductPrice row effective_at fixed | NOT RUN | Symbolic prices only |
| M10 | supabase_seed | product_price_history | `P84SANDBOX0010`, PURCHASE rows 101 at `2026-05-08 10:00:00 UTC`, 202 at `2026-05-08 11:00:00 UTC` | 10 read/apply ordering check | ProductPriceSummary last=202 prev=101 | ProductPriceHistory sorted by effective_at; no duplicates | 2 unique rows by owner/product/type/effective_at | NOT RUN | Fixed UTC timestamps |
| M11 | supabase_seed | duplicate_barcode | duplicate attempt for `P84SANDBOX0011` | 11 create active row, then duplicate same owner/barcode | Android future sync reports skip/block/conflict, not silent duplicate | iOS future preview/apply reports conflict/block, not silent duplicate | Unique active barcode prevents second active row | NOT RUN | Controlled duplicate only |
| M12 | android_then_ios | timestamp_conflict | `P84SANDBOX0012`, Android update `21:40`, iOS stale update `21:39` | 12 multi-writer conflict | Android keeps newer or reports conflict | iOS blocks/requires recheck, no silent overwrite | `updated_at`/baseline determines stale behavior for catalog | NOT RUN | Uses fake timestamps |
| M13 | android_or_ios | tombstone_product | `P84SANDBOX0013`, catalog delete/tombstone | 13 mark catalog product deleted_at `2026-05-08 21:45:00 UTC` | Android removes/marks deleted if no local dirty conflict | iOS remoteDeletedAt/preview/apply handles tombstone or blocks | `inventory_products.deleted_at` set; no physical cleanup | NOT RUN | Catalog tombstone only; ProductPrice tombstone is SCHEMA_GAP |
| M14 | ios_or_android | sync_event | client id `TASK084-M14-P84SANDBOX0014`, domain `catalog`, event `catalog_changed`, changed_count `1` | 14 enqueue/record activity in future authorized run | Activity registered or pending count changes | Activity registered/waiting/not registerable summary | 1 `sync_events` row idempotent by client_event_id | NOT RUN | No payload dump; ids sandbox only |
| M15 | excel_fixture | excel_row_error | row barcode empty, product `P84 Sandbox Bad Row` | 15 import analysis only | Android rejects with barcode required | iOS should reject; current evidence suggests at least missing barcode is rejected | No Supabase write | NOT RUN | Local fixture only |
| M16 | excel_fixture | excel_row_valid | `P84SANDBOX0016`, product `P84 Sandbox Product 16`, price `101` | 16 import analysis/apply future | Android accepts row and counts create | iOS accepts row and counts create | No Supabase write until separate sync | NOT RUN | Local fixture only |
| M17 | excel_fixture | export_reimport | full DB export containing M1/M6/M7/M10 subset | 17 export then reimport idempotency future | Android reimport does not duplicate active products/prices | iOS reimport does not duplicate active products/prices | Supabase unchanged unless later sync authorized | NOT RUN | File contains only P84SANDBOX keys |

### Regole di normalizzazione rilevate / da decidere

| Area | Android | iOS | Supabase | Decisione proposta | Stato |
|------|---------|-----|----------|--------------------|-------|
| Barcode trim / zero iniziali | Import and catalog boundary trim; preserves case/zeroes for catalog key | `semanticString` trims whitespaces/newlines; preserves zeroes | `barcode text`, unique active exact value | Treat barcode as string; trim boundary whitespace; preserve leading zeroes and case. | PARTIAL |
| Nome prodotto | Import trims, compares case-insensitive; max 100 in Android import | Trim only; no max observed in core import | `product_name text` nullable | Manifest uses short exact names; decide whether iOS should mirror Android validation in follow-up. | PARTIAL |
| Second product name | Trim + max 100 Android import | Trim only | `second_product_name text` nullable | Preserve if present; do not require unless primary name missing policy is decided. | PARTIAL |
| Prezzi e arrotondamenti | Import round3 for purchase/retail; dirty tolerance 0.001 | ProductPrice canonical scale 3; catalog fingerprint scale 6; import `Double` direct | double precision; no scale constraint | Use integer symbolic values 101/202/303 for P84; decide decimal tolerance before runtime. | PARTIAL |
| Timestamp timezone | ProductPrice strings `yyyy-MM-dd HH:mm:ss`; tombstone ISO instant for Android | ProductPrice canonical UTC `yyyy-MM-dd HH:mm:ss`; catalog `updated_at` parsed as date | `updated_at/deleted_at timestamptz`; price timestamps text | Manifest timestamps UTC explicit; never implicit `now`. | PARTIAL |
| Supplier/category matching | Android relation key trim, lower, accent-insensitive; Category Room NOCASE | iOS trim/lower for preview lookup; import resolver trim only | unique lower active | For sandbox use ASCII exact names; accent/case policy is follow-up. | PARTIAL |
| Excel header alias | Android broad alias list incl. old price, discount, real quantity | iOS broad alias list but not identical; generated mandatory columns inserted | N/A | P84 fixture uses canonical headers plus one explicit alias check; no claim full alias parity. | PARTIAL |
| Export/import DB columns | Android Products includes old purchase/retail; Suppliers/Categories include id/name; PriceHistory sheet | iOS Products omits old purchase/retail; Suppliers/Categories name only; PriceHistory sheet | N/A | Mark round-trip parity PARTIAL until a fixture proves cross-import idempotency or a format contract is chosen. | PARTIAL |

### P84-C preparatorio — schede future, non runtime

| Scenario | Manifest richiesto | Preflight | Check atteso | Stop conditions | Dati da osservare | Stato |
|----------|--------------------|-----------|--------------|-----------------|-------------------|-------|
| P84-02 Android → Supabase → iOS prodotto nuovo | M2 + M6 + M7; optionally M14 | Manifest approved; owner test known; Android repo clean enough for run; Supabase sandbox allowed; iOS runtime explicitly authorized later | iOS sees barcode M2, product fields, supplier/category links; no duplicate; ProductPrice not implied unless M8/M10 attached | owner/RLS unclear; Android write not authorized; iOS runtime not authorized; duplicate/conflict appears without plan; manifest keys absent | Android local row count, Supabase active product/supplier/category count, iOS local visible product count | PLANNED / NOT RUN |
| P84-03 iOS → Supabase → Android prodotto nuovo | M3 + M6 + M7; optionally M14 | Manifest approved; iOS push authorized later; recheck session/account/owner/baseline before write; Android sync path selected | Android sees barcode M3, product fields, supplier/category links; no duplicate; UI summary honest | iOS write not authorized; runtime not authorized; plan stale; Android sync would require cleanup/reset | iOS local row, Supabase active product count, Android ProductWithDetails count | PLANNED / NOT RUN |
| P84-06 Supplier / category parity | M6 + M7 with product M2 or M3 | Manifest approved; decide origin platform; FK ordering explicit | Supplier/category created once, linked to product, no orphan FK, no duplicate by case/trim | name normalization ambiguous; remote refs missing; unique conflict without recovery path; runtime/write not authorized | Supplier/category row counts, remote ids, product FK resolution on both clients | PLANNED / NOT RUN |

### Gap summary

Conteggio documentale su voci principali P84-A/field-mapping/manifest; non e' un risultato di test runtime.

| Categoria | Conteggio | Voci principali | Routing |
|-----------|-----------|-----------------|---------|
| MATCH | 7 | Static contract `sync_events`; barcode; catalog `owner_user_id`; catalog `deleted_at`; ProductPrice parent/type/price/effective_at/client_event fields | no action, evidence follow-up for runtime |
| ACCEPTED_NATIVE_IOS | 0 | Nessuna differenza UX marcata come accettata senza runtime o scenario UI | evidence follow-up |
| PARTIAL | 10 | Product/Supplier/Category mapping; ProductPrice id strategy; current/previous price; import Excel; export DB; normalization; conflict/timestamp | iOS follow-up, Android follow-up, manifest follow-up, evidence follow-up |
| MISSING_IOS | 2 | `ProductPrice.remoteID` persistito assente su iOS; old purchase/old retail fields/export not present as Android fields | iOS follow-up |
| MISSING_ANDROID | 1 | `updated_at` catalogo non decodificato nei row Android letti | Android follow-up |
| SCHEMA_GAP | 3 | No definitive HistoryEntry cloud table; ProductPrice no `updated_at`; ProductPrice no `deleted_at` tombstone column | Supabase/backend follow-up |
| BLOCKED_MANIFEST | 0 | Manifest M1…M17 e' compilato documentale; tutti runtime NOT RUN | no action until review |
| OUT_OF_SCOPE_TASK_084 | 1 | Dataset medio/performance e hardening production | TASK-085 |

### Modifiche fatte

- Promosso tracking TASK-084 a **ACTIVE / EXECUTION** in `docs/MASTER-PLAN.md`.
- Dopo completamento della slice read-only autorizzata, preparato handoff **ACTIVE / REVIEW** verso **Claude / Reviewer**.
- Aggiunta sezione Execution con baseline, letture read-only, P84-A mapping, field mapping P0/P1, manifest M1…M17, normalizzazione, P84-C preparatorio e gap summary.
- Nessun file Swift/Kotlin/SQL/backend/project/localization modificato.

### Check eseguiti

| Check | Stato | Evidenza |
|-------|-------|----------|
| Build compila (Xcode / BuildProject) | ⚠️ NON ESEGUIBILE | Non eseguito per esplicito perimetro utente: execution solo markdown/read-only; `xcodebuild` non autorizzato. |
| Nessun warning nuovo introdotto | ⚠️ NON ESEGUIBILE | Non verificabile senza build; nessun codice applicativo modificato. |
| Modifiche coerenti con il planning | ✅ ESEGUITO | Scope rispettato: solo tracking markdown, letture statiche repo-grounded, nessun runtime/write/patch codice, TASK-085 non aperto. |
| Criteri autorizzati P84-A/P84-B/P84-C | ✅ ESEGUITO | P84-A mapping statico compilato; P84-B manifest M1…M17 documentale compilato; P84-C solo schede future P84-02/P84-03/P84-06 PLANNED / NOT RUN. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun whitespace error rilevato nel diff tracciato. Nota: il task file risulta untracked nello status git, quindi `git diff --check` non lo include come file tracciato. |
| `git status --short` | ✅ ESEGUITO | Atteso per tracking: `M docs/MASTER-PLAN.md`; `?? docs/TASKS/TASK-084-android-ios-cross-platform-parity.md`. |

### Rischi rimasti

- Il mapping e' statico: nessuno scenario P84 e' stato eseguito in app o su Supabase.
- Android repo e' dirty su `gradle/libs.versions.toml`; non e' stato ispezionato oltre lo status per evitare scope creep.
- Supabase locale e' leggibile ma non e' una working tree git; lo status/commit non sono disponibili.
- `updated_at` catalogo e strategie ProductPrice remote id/tombstone richiedono review tecnica prima di autorizzare runtime.
- Export/reimport cross-platform resta PARTIAL: formati simili ma non identici.

---

## Handoff post-execution *(storico, consumato in review)*

- **READY FOR DOCUMENTAL REVIEW**
- **Stato al termine execution:** **TASK-084 ACTIVE / REVIEW**, **NON DONE** prima della review documentale.
- **Stato dopo review:** consumato dalla sezione **Review (Codex / Reviewer)** e chiuso in **Chiusura**.
- **TASK-085 NON APERTO**
- **P84-A stato:** COMPLETATO STATICO / PARTIAL — mapping Android ↔ Supabase ↔ iOS compilato, con gap espliciti e nessun MATCH usato senza lettura delle tre fonti o nota.
- **P84-B stato:** COMPLETATO DOCUMENTALE / NOT RUN — manifest sandbox M1…M17 compilato con chiavi `P84SANDBOX*`, prezzi simbolici e timestamp espliciti; nessun dato live creato.
- **P84-C stato:** PLANNED / NOT RUN — solo schede future P84-02, P84-03, P84-06; nessun runtime, nessun sync reale, nessun write.
- **Gate per non proseguire automaticamente:** runtime iOS/Android, write Supabase, ProductPrice live, drain outbox, push catalogo e dataset medio restano non autorizzati.
- **Prossima azione consigliata:** review documentale del mapping e del manifest; poi scegliere se completare/raffinare manifest e routing follow-up oppure autorizzare una futura execution runtime solo su gate PASS/PARTIAL esplicitati.

---

## Review (Codex / Reviewer) — 2026-05-08 21:23 -0400

### Esito review

**APPROVED_FOR_CLOSURE / DONE**, con perimetro esplicito: review documentale della slice read-only cross-platform.

La review conferma che TASK-084 documenta correttamente P84-A, P84-B e P84-C senza trasformare la gap analysis in un claim di parità runtime. La chiusura è coerente perché i risultati richiesti per questa slice sono documentali: mapping statico Android ↔ Supabase ↔ iOS, manifest sandbox M1…M17, gap summary e routing follow-up.

### Verifiche documentali

| Verifica | Esito | Evidenza |
|----------|-------|----------|
| Coerenza MASTER-PLAN ↔ TASK-084 prima della chiusura | ✅ ESEGUITO | MASTER indicava TASK-084 **ACTIVE / REVIEW** e TASK-085 **TODO / Planning**; il file task era **ACTIVE / REVIEW** prima di questa sezione. |
| TASK-083 chiuso | ✅ ESEGUITO | TASK-083 risulta **DONE / Chiusura** con runtime S83 non PASS e manifest incompleto documentato. |
| Claim falsi o troppo forti | ✅ ESEGUITO | Nessun claim di parità completa, runtime cross-platform PASS, write Supabase eseguito, ProductPrice live PASS, outbox drain PASS o dataset medio validato per TASK-084. |
| P84-A | ✅ ESEGUITO | Stato accettato come **COMPLETATO STATICO / PARTIAL**: mapping e field mapping compilati, gap dichiarati, runtime NOT RUN. |
| P84-B | ✅ ESEGUITO | Stato accettato come **COMPLETATO DOCUMENTALE / NOT RUN**: manifest M1…M17 compilato con dati sandbox e nessun dato live. |
| P84-C | ✅ ESEGUITO | Stato accettato come **PLANNED / NOT RUN**: solo schede P84-02/P84-03/P84-06, nessun sync reale. |
| Gap principali | ✅ ESEGUITO | Presenti: `ProductPrice.remoteID` iOS `MISSING_IOS`; `updated_at` catalogo Android `MISSING_ANDROID`; `HistoryEntry` cloud e ProductPrice `updated_at/deleted_at` `SCHEMA_GAP`; import/export e current/previous price `PARTIAL`. |
| Anti-scope | ✅ ESEGUITO | Confermati: nessun runtime iOS/Android, nessun write Supabase, nessun drain, nessun push catalogo/ProductPrice live, nessun dataset medio/negozio, nessuna patch Swift/Kotlin/SQL/localization/project, nessun TASK-085. |

### Correzioni review

- Aggiornati i campi globali del task a **DONE / CHIUSURA**, responsabile **Codex / Reviewer**.
- Reso l'handoff post-execution esplicitamente storico, per evitare contraddizione con la chiusura.
- Aggiunta chiusura esplicita: DONE documentale non equivale a parità runtime completa.

### Check finali review

| Check | Stato | Evidenza / motivo |
|-------|-------|-------------------|
| `git diff --check` | ✅ ESEGUITO | PASS, nessun output. Nota: il file TASK-084 risulta untracked, quindi questo check copre il diff tracciato e non include il contenuto del nuovo file non ancora aggiunto a Git. |
| `git status --short` | ✅ ESEGUITO | `M docs/MASTER-PLAN.md`; `?? docs/TASKS/TASK-084-android-ios-cross-platform-parity.md`. |
| Build compila (Xcode / BuildProject) | ⚠️ NON ESEGUIBILE | Non eseguito per perimetro utente: review documentale, niente `xcodebuild`. |
| Runtime iOS/Android | ⚠️ NON ESEGUIBILE | Non eseguito per perimetro utente: niente runtime o smoke. |
| Write Supabase / drain / push live | ⚠️ NON ESEGUIBILE | Non eseguito per perimetro utente: nessun write remoto o drain live. |

## Chiusura

- **Stato finale:** **DONE**.
- **Fase finale:** **CHIUSURA**.
- **Responsabile chiusura:** **Codex / Reviewer**.
- **Esito di chiusura:** review documentale approvata della slice read-only cross-platform.
- **Cosa è DONE:** mapping statico Android ↔ Supabase ↔ iOS; manifest sandbox M1…M17 documentale; gap summary; routing follow-up; P84-C preparatorio **PLANNED / NOT RUN**.
- **Cosa NON è DONE / NON eseguito:** parità Android ↔ iOS runtime completa; smoke cross-platform PASS; sincronizzazione reale dati Android/iOS; write Supabase; ProductPrice live; outbox drain live; dataset medio; dataset negozio reale; patch Swift/Kotlin/SQL; TASK-085.
- **Gap principali rimasti:** ProductPrice remote id non persistito su iOS; `updated_at` catalogo non decodificato nei row Android letti; HistoryEntry cloud non definitivo; ProductPrice senza `updated_at`/`deleted_at`; import/export e current/previous price ancora PARTIAL.
- **Follow-up consigliati:** review/raffinamento manifest e normalizzazioni; eventuali task separati iOS/Android/Supabase per i gap; futura execution runtime solo con override esplicito e gate P84-A/P84-B accettati.
- **Nota esplicita:** **TASK-084 DONE / Chiusura non equivale a parità runtime completa; equivale a chiusura documentale approvata della slice read-only P84-A/P84-B/P84-C.**

---

*Fine documento chiusura TASK-084.*
