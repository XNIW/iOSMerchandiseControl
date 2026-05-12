# TASK-086 — Fix/policy backend `updated_at` catalogo Supabase

## 1. Stato task

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-086** |
| **Stato / fase** | **DONE / Chiusura** |
| **File task** | `docs/TASKS/TASK-086-supabase-updated-at-policy-catalog-ios.md` |
| **Responsabile attuale** | **Utente / chiusura confermata da review** |
| **NON DONE** | No — chiuso dopo review severa TASK-086 con verdetto APPROVED. |
| **READY FOR EXECUTION** | Eseguita e chiusa — S86-A…S86-F reviewate. |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-12 19:18 -0400 — legacy alignment: backend `updated_at` catalogo gia chiuso; runtime cross-platform partial successivamente coperto da TASK-087/TASK-098/TASK-103; vedi `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md` |
| **Ultimo agente** | Codex / Reviewer |

> **Chiusura legacy 2026-05-12:** il riferimento storico a runtime cross-platform `PARTIAL` e' superato dalle evidenze TASK-087/TASK-098/TASK-103; il task resta `DONE / Chiusura` senza claim production-ready globale.

---

## 2. Obiettivo

Definire in modo **sicuro e verificabile** come far sì che il campo **`updated_at`** delle tabelle **catalogo** su Supabase (`inventory_suppliers`, `inventory_categories`, `inventory_products`) rifletta correttamente **ogni modifica rilevante** (update “normale”), mantenendo coerenza con:

- **iOS** — uso di `remoteUpdatedAt` / baseline per preview, apply, push preflight, stale/conflict;
- **Android** — persistenza `remoteUpdatedAt` nei bridge Room (v16) e DTO con `updated_at`;
- **sync manuale** — policy timestamp-first e fingerprint senza promettere PASS su stale/conflict se il clock remoto non avanza.

**Non** ambire in questo planning a risolvere ProductPrice tabellare (`inventory_product_prices` usa `effective_at` / eventi tombstone; `updated_at` colonna non è nel perimetro catalogo).

---

## 3. Contesto da TASK-085

- **TASK-085** è chiuso come **DONE / Chiusura** con esito di prodotto documentato **PARTIAL_ACCEPTED** — hardening e slice S85-A…S85-G non equivalgono a “production-ready 100%”.
- **Gap residuo ufficiale (backend):** su ambiente remoto controllato (`TASK085_*`), `updated_at` è stato osservato **valorizzato all’insert** ma **non avanza** su update normale (`updated_at_advanced=false` negli esiti di collaudo documentati).
- **Conseguenza:** la catena **stale / baseline / conflitto** che dipende dal confronto tra **ultimo `updated_at` remoto osservato** e **modifiche locali** resta dichiarabile solo come **PARTIAL**, non **PASS**, finché la semantica remota non è affidabile.
- TASK-085 ha già allineato **client-side** (es. Android decode + Room v16; iOS già consumava `updated_at` come `remoteUpdatedAt`). Il **residuo** è **prevalentemente server-side/policy**.

---

## 4. Stato attuale iOS

**Lettura e uso di `remoteUpdatedAt`**

- I DTO / servizi di pull decodificano `updated_at` remoto e lo mappano su **`Supplier` / `ProductCategory` / `Product`** come **`remoteUpdatedAt`** (oltre a `remoteDeletedAt` per tombstone).
- **`SupabasePullApplyService`** propaga `remoteUpdatedAt` / `remoteDeletedAt` in apply (es. `applyRemoteMetadata` verso Supplier/Category).
- **Preview** (`SupabasePullPreviewService`) e metriche conflitto/tombstone dipendono dai campi remotti letti.
- **Push catalogo — preflight** (`SupabaseManualPushPreflightService`): per **supplier/category** confronta **baseline `remoteUpdatedAt`** vs **locale**; ramo **product/productPrice** conservativo con `blockedRemoteConflict` dove applicabile.
- **Baseline** (`SupabaseCatalogBaselineReader` / modelli baseline): fotografia post-pull per staleness; mappe `remoteUpdatedAtBySupplierID` / category / uso in candidati push.

**Impatto del gap backend**

- Se il server **non aggiorna** `updated_at` su PATCH/UPDATE reali, i client possono vedere **lo stesso timestamp** dopo modifiche remote successive → **falsa sensazione di “non stale”**, o **warning/conflict** incoerenti con la realtà multi-device.

**Cosa non va cambiato “solo perché TASK-086 è planning”**

- Nessuna modifica Swift è nel perimetro **TASK-086 planning**; i client **già** consumano il campo se presente. La priorità è **semantica remota affidabile** + evidenze; eventuali ritocchi client vanno valutati **solo dopo** chiarimento backend (slice **S86-D** sotto), per evitare workaround che mascherano il bug server.

---

## 5. Stato attuale Android

- **S85-C2 (TASK-085 execution):** i DTO catalogo decodificano **`updated_at`**; i bridge **`SupplierRemoteRef` / `CategoryRemoteRef` / `ProductRemoteRef`** persistono **`remoteUpdatedAt`**; migrazione **Room 15→16** aggiunge le colonne; test/repository aggiornati (dettaglio nei file Android, non modificati qui).
- **TASK-086** = **planning-only**: **nessuna patch Kotlin** autorizzata nel perimetro di questo file; Android è **riferimento** per capire che il client **è pronto** a ricevere timestamp corretti se il backend li produce.
- Nota funzionale: in codice di catalogo Android compaiono stringhe di capacità/flags che includono segnali tipo **`products_updated_at_untrusted`** — coerente con il sospetto documentale che il clock remoto catalogo non sia ancora considerato “autorità” finché il backend non è corretto.

---

## 6. Stato attuale Supabase

### 6.1 Schema / migrazioni **nel clone locale** (fonte: `/Users/minxiang/Desktop/MerchandiseControlSupabase`)

**Catalogo (`task013` / `inventory_catalog_rls.sql`)**

- `inventory_suppliers`, `inventory_categories`, `inventory_products`: colonna **`updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`**.
- **RLS** `authenticated`: SELECT/INSERT/UPDATE/DELETE con `auth.uid() = owner_user_id` (delete su catalogo — evoluzione successiva in task 038 vedi sotto).
- **Nessun** `CREATE TRIGGER` per `set_updated_at` in questo file; l’aggiornamento automatico su **UPDATE** non è definito qui — il valore default si applica principalmente a **INSERT**.

**Tombstone (`task019` / `inventory_catalog_tombstone.sql`)**

- Aggiunta **`deleted_at`** alle tre tabelle catalogo; **partial UNIQUE** “attivo” solo se `deleted_at IS NULL`.
- Trigger **`inventory_catalog_block_update_when_tombstoned`**: BEFORE UPDATE — se `OLD.deleted_at IS NOT NULL`, la funzione termina con **`RETURN OLD`** (vedi SQL in `task019`; su Postgres tipicamente questo impedisce l’applicazione dell’UPDATE alla riga tombstonata; validare su versione target).
- **Nessun** trigger che imposti `updated_at` insieme a tombstone in questo file (la logica tombstone + timestamp “di cambio stato” va esplicitata in design/migration future).

**Prezzi (`task016` / `inventory_product_prices`)**

- Colonne: `effective_at text`, `created_at text`, **nessun** `updated_at` tabellare — allineato a modello “append-only + vincoli” e a eventi dominio (`sync_events`).

**Delete policy (`task038`)**

- Revoca **DELETE** a ruolo `authenticated` su catalogo + prezzi (allineamento tombstone / append-only documentato nel commento migration).

**`sync_events` (`task045`)**

- Tipi dominio inclusi `catalog_tombstone`, `prices_tombstone`, ecc. — possibile **segnale parallelo** a livello evento, distinto dal solo `updated_at` riga.

### 6.2 Remoto verificato (evidenza indiretta da journaling MASTER-PLAN / TASK-085)

- Audit read-only su progetto collegato ha riportato: **nessun trigger `set_updated_at`** sulle tabelle catalogo; **trigger tombstone** presenti; **`updated_at` inserito ma non avanzante** su update controllato seed `TASK085_*`.
- **Assunzione da validare** prima di ddl: lo schema **remoto** corrisponde alle migrazioni del repo (salvo hotfix esterni) — rischio **drift** va esplicitamente controllato in **S86-A**.

### 6.3 Sintesi gap

| Aspetto | Stato |
|--------|--------|
| `updated_at` default INSERT | Presente (DEFAULT) |
| `updated_at` su UPDATE normale | **Non garantito** dai file migration letti; coerente con gap osservato |
| Tombstone / `deleted_at` | Trigger dedicati |
| Prezzi / conflict | `effective_at` + eventi; **fuori** perimetro “catalog `updated_at`” |

---

## 7. Opzioni tecniche

### Opzione A — Trigger additivo `set_updated_at` (catalogo: suppliers, categories, products)

| Voce | Contenuto |
|------|-----------|
| **Pro** | Un solo punto di verità lato DB; i client non devono ricordarsi di bumpare il timestamp; coerente con pattern Postgres comune. |
| **Contro** | Ordine trigger vs tombstone (`BEFORE UPDATE`), naming e `EXECUTE` su funzione condivisa; richiede migration + test in sandbox; attenzione a UPDATE “no-op” o riscritture. |
| **Rischio dati** | Basso se limitato a `NEW.updated_at`; errore di ordine/logica può **bloccare** update legittimi o **non aggiornare** quando serve. |
| **Impatto iOS** | Positivo: `remoteUpdatedAt` rifletterà modifiche reali → preflight/baseline più affidabili. |
| **Impatto Android** | Positivo: stesso segnale nelle ref Room. |
| **Impatto Supabase/RLS** | Nessun cambio policy se il trigger è su tabella **per lo stesso owner**; verificare compatibilità con **replica/pooler** (solo osservazione operativa, non blocco di principio). |
| **Test necessari** | SQL: INSERT → `updated_at` valorizzato; UPDATE campo qualsiasi → `updated_at` > precedente; UPDATE tombstone path → non violare `deleted_at` / anti-resurrezione; due update consecutivi. |
| **Rollback** | Migration inversa `DROP TRIGGER` / `DROP FUNCTION` se isolati; snapshot progetto noto. |

### Opzione B — Client aggiorna `updated_at` esplicitamente (PostgREST payload)

| Voce | Contenuto |
|------|-----------|
| **Pro** | Nessun ddl immediato; controllo fine su **chi** bumpa. |
| **Contro** | Duplicazione logica **iOS + Android**; rischio **dimenticanze** su patch future; client malevolo o bug può inviare timestamp arbitrari (**sicurezza semantica** peggiore rispetto al trigger). |
| **Rischio dati** | Medio — divergenza versioni client, clock skew orchestrato male. |
| **Impatto iOS** | Ogni write catalogo deve includere campo; più codice e test. |
| **Impatto Android** | Idem. |
| **Impatto Supabase/RLS** | Potrebbe servire **policy** che **vieti** spoofing (difficile senza trigger trusted). |
| **Test necessari** | Matrice build Android/iOS; regression push/apply; edge tombstone. |
| **Rollback** | Ripristino commit client; dati già scritti possono avere timestamp “strani”. |

### Opzione C — Solo `sync_events` / “revision” come segnale conflitto (senza `updated_at` affidabile)

| Voce | Contenuto |
|------|-----------|
| **Pro** | Evento dominio esplicito; utile per audit e outbox già presente. |
| **Contro** | Non sostituisce una colonna **per riga** per confronto LWW/baseline su **stessa riga catalogo** senza join pesanti; ordering tra eventi e stato tabellare più complesso. |
| **Rischio dati** | Medio-alto se usato **solo** per conflict senza `updated_at` — gap su UX “ultima modifica riga”. |
| **Impatto iOS** | Rifattura significativa policy conflict (oggi allineata a `updated_at` + fingerprint). |
| **Impatto Android** | Simile. |
| **Impatto Supabase/RLS** | Dipende da pipeline `record_sync_event` e consistenza. |
| **Test necessari** | End-to-end eventi + stato tabellare; maggiore superficie. |
| **Rollback** | Complesso — sconsigliato come **unica** soluzione per il gap TASK-085. |

### Opzione D — Approccio ibrido

| Voce | Contenuto |
|------|-----------|
| **Pro** | **A + C**: trigger per verità locale della riga; eventi per notifiche e correlazione multi-entità. |
| **Contro** | Due sorgenti da mantenere coerenti; rischio duplicazione concettuale se non documentato. |
| **Rischio dati** | Da contenere con regole chiare (es. trigger = source of row truth; event = audit). |
| **Impatto iOS/Android** | Minimo ulteriore rispetto ad A se i client restano su `updated_at`. |
| **Impatto Supabase/RLS** | Moderato — eventuali funzioni RPC o queue. |
| **Test necessari** | Combinazione test Opzione A + verifica `sync_events` opzionale. |
| **Rollback** | Come A; disattivare eventi aggiuntivi se aggiunti. |

---

## 8. Raccomandazione planning (provvisoria)

**Preferenza conservativa: Opzione A** (trigger additivi `set_updated_at` sulle tre tabelle catalogo, con funzione SECURITY DEFINER **no** — solo `plpgsql` standard; ordine trigger verificato rispetto ai BEFORE UPDATE esistenti).

**Motivazione:** minimo supposto lato client già allineato post-TASK-085; riduce rischio di spoofing timestamp; allineamento comune con l’intento del campo `updated_at`; rollback e test SQL circoscritti.

**Opzione D** è seconda scelta se il prodotto richiede anche **eventi** espliciti per telemetria — ma **non** come sostituto del bump tabellare per questo gap.


**Non applicare nulla** finché non passa **S86-A–S86-C** con esito positivo e consenso write.

### 8.1 Decisione di planning proposta

Per evitare ambiguita' nelle slice future, la decisione provvisoria di TASK-086 e':

- **scelta primaria:** **Opzione A — trigger additivo DB-side** su `inventory_suppliers`, `inventory_categories`, `inventory_products`;
- **fallback:** **Opzione D — ibrido**, ma solo come estensione futura per osservabilita'/audit, non come sostituto del bump tabellare;
- **scartata per default:** **Opzione B client-side**, perche' peggiora UX/affidabilita' multi-device: iOS e Android potrebbero divergere e il timestamp diventerebbe responsabilita' del client invece che del backend;
- **scartata come soluzione unica:** **Opzione C sync_events-only**, perche' non offre un segnale semplice, per-riga, adatto alla baseline catalogo gia' usata dai client.

La migration futura dovrebbe essere **minima e additiva**: funzione `set_updated_at` idempotente + tre trigger catalogo. Nessun backfill massivo e nessun update dati reali devono essere parte della prima execution.

### 8.2 Guardrail tecnici per la migration futura

La futura migration non va ancora scritta/eseguita in TASK-086 planning, ma quando verrà preparata in execution dovrà rispettare questi criteri:

- **DB come source of truth del timestamp:** il trigger deve gestire `NEW.updated_at` lato database, evitando che i client possano decidere timestamp arbitrari.
- **Clock Postgres esplicito:** in execution scegliere e documentare una sola sorgente tempo. Raccomandazione provvisoria: `statement_timestamp()` o `now()` lato DB, non clock client. Se si mantiene lo stile legacy `timezone('utc', now())`, verificare esplicitamente il cast verso `timestamptz` per evitare ambiguità timezone.
- **Semantica monotona realistica:** non promettere monotonicità assoluta per update multipli nella stessa transazione se si usa `now()`; per la UX e il preflight basta che update reali successivi siano osservabili con precisione sufficiente da iOS/Android.
- **Nessun backfill automatico:** non fare `UPDATE` massivi sulle tabelle reali solo per aggiornare timestamp storici; TASK-086 risolve la semantica futura, non riscrive la storia.
- **Funzione unica, trigger separati:** preferire una funzione riusabile + tre trigger espliciti su `inventory_suppliers`, `inventory_categories`, `inventory_products`, con naming chiaro e idempotente.
- **Compatibilità tombstone:** validare ordine/interazione con `inventory_catalog_block_update_when_tombstoned`; una riga già tombstoned non deve essere modificata o resuscitata dal trigger. In execution, documentare se il trigger `updated_at` deve girare prima/dopo il blocco tombstone o se la funzione deve uscire senza cambiare `NEW` quando `OLD.deleted_at IS NOT NULL`.
- **No-op update documentato:** decidere esplicitamente se un `UPDATE` fisico senza cambio logico deve bumpare `updated_at`; scelta provvisoria consigliata: evitare PATCH no-op lato client, ma accettare che il DB bumpi quando riceve un vero UPDATE.
- **Precisione timestamp:** verificare che i client iOS/Android non tronchino la precisione in modo da rendere indistinguibili update ravvicinati.
- **Rollback semplice:** ogni trigger/funzione aggiunta deve avere rollback commentato (`DROP TRIGGER IF EXISTS ...`, `DROP FUNCTION IF EXISTS ...`) senza toccare dati.

### 8.2.1 Sketch SQL non eseguibile — solo design

Questo non è codice autorizzato per execution. Serve solo a fissare la forma attesa della futura migration:

```sql
-- DESIGN ONLY / NON ESEGUIRE IN PLANNING
-- funzione idempotente per aggiornare updated_at lato DB
-- trigger separati per inventory_suppliers, inventory_categories, inventory_products
-- rollback commentato con DROP TRIGGER IF EXISTS + DROP FUNCTION IF EXISTS
```

### 8.3 Criterio UX/UI collegato

TASK-086 e' backend/policy, ma il risultato influenza direttamente la UX della sync manuale iOS. La regola per le slice successive e':

- finche' `updated_at` non e' affidabile, la UI Release deve usare copy prudente tipo **"Controllo completato"**, **"Da rivedere"**, **"Possibili modifiche remote"**;
- dopo evidenze PASS su `updated_at`, la UI puo' mostrare stati piu' forti come **"Aggiornato"** / **"Nessuna modifica trovata"**, ma solo se preview, baseline e timestamp concordano;
- evitare nella UI utente parole tecniche come `updated_at`, `baseline`, `trigger`, `RPC`, `RLS`, `sync_events`;
- se emerge una scelta UI durante execution, preferire sheet SwiftUI nativa, CTA unica primaria, copy breve e coerente con `OptionsView` / flusso **Controlla cloud → Rivedi → Conferma**.
- **evitare nuove superfici UI** per TASK-086 se non necessarie: la UI migliore qui è meno confusione, non più schermate;
- **se serve un micro-ritocco UX futuro**, limitarsi a copy/stati/summary nella sheet esistente, senza redesign ampio;
- **in caso di scelta tra chiarezza tecnica e chiarezza utente**, scegliere chiarezza utente: il dettaglio tecnico resta in log/report, non nella UI Release.

---

## 9. Micro-slice future (invocabili solo con override)

| Slice | Descrizione | Output atteso | Gate stop |
|-------|-------------|---------------|-----------|
| **S86-A** | Schema audit **read-only** locale + remoto se autorizzato: trigger, funzioni, RLS, grants, migration applicate, eventuale drift rispetto al repo. | Report diff schema locale/remoto + conferma se manca davvero `set_updated_at`. | Stop se remoto diverge in modo non spiegato o se accesso/pooler instabile impedisce evidenze affidabili. |
| **S86-B** | **Migration draft** solo in working tree / branch — funzione idempotente + trigger catalogo, senza `db push`. | File SQL draft con rollback commentato e naming stabile. | Stop se serve toccare dati reali, backfill o policy RLS non previste. |
| **S86-C** | Test SQL in **sandbox** o database effimero: INSERT, UPDATE normale, UPDATE no-op, tombstone, update riga gia' tombstoned, doppio update ravvicinato. | Matrice PASS/FAIL con `updated_at_advanced=true` dove previsto. | Stop se il trigger rompe tombstone/anti-resurrezione o produce timestamp non monotoni. |
| **S86-D** | Patch client **solo se necessaria** dopo S86-C: select missing, parsing timestamp, copy UI prudente, test fakeable. | Diff Swift/Kotlin opzionale e motivato; preferire nessuna patch se client gia' compatibili. | Stop se la patch client tenta di compensare un bug backend non risolto. |
| **S86-E** | Smoke sandbox prefissato `TASK086_*`: update supplier/category/product da un lato, pull/read-back dall'altro lato. | Evidenze privacy-safe iOS + Android + Supabase read-back. | Stop se uno dei due client vede timestamp stale o dati non coerenti. |
| **S86-F** | Review / acceptance con evidenze e aggiornamento tracking. | Verdetto `APPROVED`, `CHANGES_REQUIRED` o `PARTIAL`, senza claim 100% se TASK-087…090 non sono passati. | Stop se mancano log, snapshot, query o mapping impatto iOS/Android. |

---

## 9.1 Matrice minima di verifica futura

| Scenario | Azione | Risultato atteso |
|----------|--------|------------------|
| Supplier update | Modificare `name` su riga `TASK086_supplier` | `updated_at` cambia e resta UTC/timestamptz valido. |
| Category update | Modificare `name` su riga `TASK086_category` | `updated_at` cambia senza rompere partial unique su attivi. |
| Product update | Modificare campo non distruttivo su `TASK086_product` | `updated_at` cambia; barcode/owner invariati. |
| No-op update | Eseguire update che non cambia valori logici | Decisione esplicita: o bump accettato come update fisico, o evitato dal client; documentare la scelta. |
| Tombstone fresh | Impostare `deleted_at` su riga attiva sandbox | `deleted_at` resta valorizzato; `updated_at` ha semantica documentata; la riga non torna attiva. |
| Tombstone already deleted | Tentare update su riga gia' tombstoned sandbox | Anti-resurrezione resta efficace; nessun dato reale toccato. |
| iOS read-back | Pull/preview iOS dopo update remoto sandbox | `remoteUpdatedAt` osservato diverso dal baseline precedente. |
| Android read-back | Pull/refresh Android dopo update remoto sandbox | `remoteUpdatedAt` persistito in ref Room v16. |
| Cross-platform stale | Device A modifica, device B prepara push da baseline vecchia | Preflight deve bloccare o avvisare, non sovrascrivere silenziosamente. |

---

## 9.2 Gate Go/No-Go per promuovere TASK-086 a EXECUTION

TASK-086 può passare da PLANNING a EXECUTION solo se tutti questi gate sono veri:

- [ ] S86-A read-only completata: schema locale e remoto confrontati; trigger/funzioni esistenti elencati; drift spiegato o assente.
- [ ] Ambiente target esplicito: sandbox/local/dev/production-like dichiarato; nessuna ambiguità su dove verrà testata la migration.
- [ ] Dataset sandbox definito: prefisso `TASK086_*`, owner/account/sessione noti, nessun dato reale usato come fixture.
- [ ] Scelta tecnica confermata: Opzione A confermata oppure alternativa documentata con motivazione forte.
- [ ] Migration draft revisionata: rollback incluso, nessun backfill massivo, nessun `UPDATE` senza WHERE, nessun cambio RLS non necessario.
- [ ] Matrice SQL pronta: insert/update/no-op/tombstone/update ravvicinati già descritti prima di toccare il remoto.
- [ ] Consenso utente esplicito: autorizzazione separata per qualunque write/DDL remoto.

**No-Go immediato se:**

- schema remoto non corrisponde al locale e non si capisce perché;
- pooler/sessione instabile impedisce read-back affidabile;
- la migration richiede cleanup/delete/truncate/reset;
- la soluzione proposta sposta la responsabilità primaria del timestamp sui client;
- la UI dovrebbe nascondere un rischio tecnico invece di comunicarlo in modo prudente.

---

## 10. Acceptance criteria futuri (post-planning / execution)

- [ ] **`updated_at` avanza** su UPDATE normale catalogo (supplier/category/product) — misurabile confrontando timestamp pre/post con stesso `id`.
- [ ] **INSERT** mantiene comportamento corretto (default iniziale + coerenza con vincoli).
- [ ] **Path tombstone**: soft-delete / `deleted_at` **non** “resuscita” righe; **`updated_at`** ha semantica documentata al bury (bump alla tombstone o no — **decisione esplicita** prima di ddl).
- [ ] **iOS** osserva nuovo timestamp su pull/baseline dopo modifica remota controllata.
- [ ] **Android** idem su Room ref / DTO.
- [ ] **Stale/conflict / preflight** possono usare `updated_at` come segnale **affidabile** negli scenari H85-09 / matrice TASK-082 — con evidenza, non ipotesi.
- [ ] **Nessun dato reale** modificato senza consenso separato; nessun cleanup distruttivo.
- [ ] **Schema audit completato:** locale e remoto verificati read-only prima di scrivere qualsiasi migration.
- [ ] **Migration additiva e rollbackabile:** trigger/funzione isolati, rollback commentato, nessun backfill dati reali.
- [ ] **UI Release coerente:** copy prudente finché non ci sono evidenze PASS; nessun jargon tecnico esposto all’utente.
- [ ] **No-op policy documentata:** deciso e testato cosa succede quando arriva un UPDATE fisico senza cambio logico.

---

## 11. Rischi

| Rischio | Nota |
|--------|------|
| **Trigger errato su dataset reale** | Ordine **BEFORE UPDATE**, interazione con anti-resurrezione; test obbligatori in sandbox. |
| **Update massivi involontari** | Backfill non richiesto; evitare `UPDATE` senza WHERE in produzione. |
| **Conflitto con tombstone** | Definire se tombstone UPDATE coincide con bump `updated_at` e se il trigger “no-op” su riga già tombstoned è raggiungibile. |
| **Schema locale ≠ remoto** | drift migrazioni — mitigato da S86-A. |
| **Pooler / circuit breaker** | Osservazione TASK-085 su instabilità temporanea lettura; non è fix `updated_at` ma può mascherare evidenze smoke. |
| **Timezone / precisione** | Usare `timestamptz` e **UTC** coerente con default esistenti. |
| **Client vecchi** | Se ignorano colonna in SELECT, `remoteUpdatedAt` resta null — mitigato se i path già selezionano `updated_at`. |
| **Precisione timestamp in update ravvicinati** | Due update nello stesso secondo potrebbero sembrare uguali se parsing/format tronca precisione; verificare precisione end-to-end iOS/Android. |
| **UI troppo ottimistica** | Se la UI mostra "sincronizzato" con timestamp non verificato, l'utente perde fiducia; copy prudente fino a smoke PASS. |
| **Trigger su campi tecnici** | Aggiornare solo metadata potrebbe bumpare `updated_at`; decidere se accettabile o se i client devono evitare PATCH no-op. |
| **Responsabilità timestamp spostata sui client** | Soluzione più fragile e meno coerente multi-device; mantenerla solo come fallback temporaneo documentato. |
| **Backfill non necessario** | Riscrivere timestamp storici può falsare baseline e creare conflitti artificiali; vietato nella prima execution salvo decisione separata. |
| **Ordine trigger non verificato** | Se il trigger `updated_at` gira in modo inatteso rispetto al tombstone trigger, può produrre semantica ambigua; testare esplicitamente. |

---

## 12. Handoff finale

1. **READY FOR PLANNING REVIEW** — contenuto TASK-086 sottomesso a revisore/utente.
2. **NON READY FOR EXECUTION** — nessuna migration applicata; nessun Swift/Kotlin/SQL live nel perimetro TASK-086 planning.
3. **TASK-086 NON DONE**.
4. **Autorizzazioni richieste prima di qualunque modifica SQL/live:**
   - esplicito **consenso write** su ambiente target (sandbox vs produzione);
   - **S86-A** completata senza sorprese di drift;
   - migration **S86-B** rivista e **S86-C** verde;
   - eventuale finestra operativa per pooler/post-check read-back.
5. **Definition of Ready per EXECUTION futura:** S86-A deve essere completata, la scelta Opzione A deve essere confermata o sostituita con decisione documentata, e l'utente deve autorizzare esplicitamente ambiente target + perimetro write.
6. **Definition of Done futura:** non basta creare il trigger; serve read-back iOS/Android e scenario stale che dimostri che il timestamp viene usato in modo sicuro dalla UX Release.
7. **Stato storico dopo la sola integrazione di planning:** restava **TASK-086 ACTIVE / PLANNING**, **NON DONE**, **NON READY FOR EXECUTION** prima dell'override utente del 2026-05-09.
8. **Nota UX:** TASK-086 non deve introdurre nuove schermate; eventuali miglioramenti UI futuri devono restare piccoli, nativi SwiftUI e coerenti con la sheet manual sync esistente.

---

## Riferimenti (solo lettura, incrociati in planning)

- **TASK-085** — chiusura PARTIAL_ACCEPTED; seed `TASK085_*`; flag `updated_at_advanced=false`.
- **TASK-082** — policy conflict / `remoteUpdatedAt` / baseline (iOS).
- **TASK-080 / 084** — ProductPrice vs catalog timestamps.
- **Repo Supabase locale** — `MerchandiseControlSupabase/supabase/migrations/` (013, 016, 019, 038, 045).

---

*Nota storica planning-only: durante la creazione e il planning hardening del 2026-05-08 non erano state eseguite modifiche a backend, codice app o dati. Lo stato corrente e' aggiornato nelle sezioni Execution e Review/Chiusura.*

## Execution

### Avvio EXECUTION — 2026-05-09

| Voce | Contenuto |
|------|-----------|
| **Override utente** | L'utente ha autorizzato esplicitamente l'intera execution controllata di TASK-086, incluse audit schema, migration additiva, test SQL `TASK086_*`, eventuale apply target se i gate passano, verifica iOS/Android e tracking finale. |
| **Obiettivo compreso** | Risolvere il gap backend `updated_at` del catalogo Supabase facendo avanzare `updated_at` su UPDATE normale per `inventory_suppliers`, `inventory_categories` e `inventory_products`, senza spostare la responsabilita' primaria sui client. |
| **File controllati iniziali** | `docs/MASTER-PLAN.md`; questo file TASK-086; riferimenti `TASK-085`, `TASK-082`, `TASK-080`, `TASK-084`; progetto Supabase locale `/Users/minxiang/Desktop/MerchandiseControlSupabase`. |
| **File da modificare previsti** | Tracking `docs/MASTER-PLAN.md`, questo file TASK-086, una migration SQL nel repo Supabase locale. Swift/Kotlin solo se i test dimostrano che il client non legge/persistisce `updated_at`. |
| **Piano minimo** | 1) S86-A audit read-only locale/remoto; 2) S86-B migration additiva con funzione `set_inventory_catalog_updated_at` e tre trigger; 3) S86-C test SQL controllati `TASK086_*`; 4) S86-D verifica client senza patch se gia' compatibili; 5) S86-E smoke/read-back limitato; 6) S86-F tracking e handoff REVIEW. |
| **Vincoli confermati** | Nessun dato reale di negozio come fixture; nessun delete/truncate/drop/reset; nessun cleanup distruttivo; nessun backfill massivo; nessun `UPDATE` massivo senza `WHERE`; nessun segreto/connection string stampato; nessun claim production-ready 100%; nessun TASK-087. |
| **Stato iniziale execution** | **ACTIVE / EXECUTION**, responsabile **Claude / Executor**, **TASK-086 NON DONE**. |

### S86-A — Schema audit read-only

| Area | Esito | Evidenza privacy-safe |
|------|-------|-----------------------|
| **Progetto Supabase locale** | ✅ ESEGUITO (STATIC) | Letti `AGENTS.md`, `MASTER_PLAN.md`, `supabase/migrations/README.md` e migration locali nel repo `/Users/minxiang/Desktop/MerchandiseControlSupabase`. Il path è leggibile ma non è una working tree git completa nel tracciamento storico del progetto. |
| **Local DB runtime** | ⚠️ NON ESEGUIBILE | `supabase db query --local` fallisce su `127.0.0.1:54322` connection refused; l'audit locale è quindi su migration files, non su database locale avviato. |
| **Tabelle catalogo locali** | ✅ ESEGUITO (STATIC) | `20260417120000_task013_inventory_catalog_rls.sql` crea `inventory_suppliers`, `inventory_categories`, `inventory_products` con `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`; `20260418200000_task019_inventory_catalog_tombstone.sql` aggiunge `deleted_at`. |
| **Prezzi locali** | ✅ ESEGUITO (STATIC) | `20260417200000_task016_inventory_product_prices.sql` definisce `inventory_product_prices` con `effective_at` / `created_at` text e senza `updated_at` / `deleted_at`; confermato fuori perimetro trigger TASK-086. |
| **Trigger/funzioni locali** | ✅ ESEGUITO (STATIC) | Presente solo funzione/trigger tombstone `inventory_catalog_block_update_when_tombstoned`; nessun trigger locale `set_updated_at` sul catalogo. |
| **RLS/grants locali** | ✅ ESEGUITO (STATIC) | RLS enabled sulle tabelle inventory; grants iniziali SELECT/INSERT/UPDATE/DELETE a `authenticated`; migration 038 rimuove DELETE per catalogo/prezzi. Nessun cambio RLS/grants richiesto da TASK-086. |
| **Remote target** | ✅ ESEGUITO | Linked project confermato in modo mascherato `jpgo...kyvm`; nessuna connection string o chiave stampata. |
| **Remote migration history** | ⚠️ PARTIAL | `supabase migration list --linked` mostra drift storico: migration locali `20260417` e `20260424021936` non risultano con lo stesso id remoto; remoto ha `20260424145010`. Lo schema effettivo target risulta però presente/coerente per catalogo, prezzi, tombstone e `sync_events`, quindi il drift è da documentare ma non blocca questa migration additiva. |
| **Remote catalog columns** | ✅ ESEGUITO | `inventory_suppliers/categories/products` hanno `id`, `owner_user_id`, campi business, `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`, `deleted_at`. `updated_at_nulls=0` sulle tre tabelle. |
| **Remote product prices** | ✅ ESEGUITO | `inventory_product_prices` ha `id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `source`, `note`, `created_at`; nessun `updated_at` / `deleted_at`. |
| **Remote triggers** | ✅ ESEGUITO | Sulle tre tabelle catalogo risultano solo `inventory_*_block_post_tombstone_update` BEFORE UPDATE → `inventory_catalog_block_update_when_tombstoned()`. Nessun trigger `set_updated_at` collegato a `inventory_suppliers`, `inventory_categories`, `inventory_products`. |
| **Remote functions** | ✅ ESEGUITO | Esistono `inventory_catalog_block_update_when_tombstoned()`, `record_sync_event(...)`, e `set_updated_at()`; `set_updated_at()` imposta `new.updated_at = now()` ma non è agganciata al catalogo. |
| **Remote RLS/grants** | ✅ ESEGUITO | RLS enabled per inventory/sync/session/history. Per inventory catalog/prices `authenticated` ha SELECT/INSERT/UPDATE, senza DELETE grant; `anon` non ha grant inventory. Nessun cambio RLS/grants previsto. |
| **Remote dataset aggregate** | ✅ ESEGUITO | Conteggi aggregati solo per audit: 82 suppliers, 45 categories, 19.700 products; `updated_at` valorizzato, 1 product tombstoned. Nessun payload business letto o usato come fixture. |

**Verdetto S86-A:** **PARTIAL / ACCEPTABLE TO PROCEED**.

Motivo: l'audit remoto è affidabile e conferma il gap richiesto; l'audit locale runtime non è eseguibile perché il DB locale non è avviato, ma le migration locali sono coerenti. Il drift nella tabella migration remota è storico e non cambia il fatto operativo rilevante: sulle tre tabelle catalogo manca il trigger `updated_at`, mentre tombstone/RLS/grants sono già presenti e non devono essere modificati.

**Decisione:** procedere a **S86-B** con migration additiva locale, senza eseguire SQL remoto prima dei test S86-C. La migration non deve toccare `inventory_product_prices`, `sync_events`, `history_entries` o `shared_sheet_sessions`.

### S86-B — Migration SQL draft

| Voce | Esito |
|------|-------|
| **File migration creato** | `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260509120000_task086_inventory_catalog_updated_at_triggers.sql` |
| **Scelta tecnica** | Trigger DB-side additivo; funzione `public.set_inventory_catalog_updated_at()`; clock Postgres `statement_timestamp()`; nessun timestamp client. |
| **Tabelle target** | Solo `public.inventory_suppliers`, `public.inventory_categories`, `public.inventory_products`. |
| **Trigger creati** | `trg_inventory_suppliers_set_updated_at`, `trg_inventory_categories_set_updated_at`, `trg_inventory_products_set_updated_at`. |
| **Tabelle escluse** | `inventory_product_prices`, `sync_events`, `history_entries`, `shared_sheet_sessions`. |
| **RLS/grants/unique** | Nessun cambio. |
| **Backfill / UPDATE dati** | Nessun backfill; nessun `UPDATE` dati nella migration. |
| **Tombstone** | Se `OLD.deleted_at IS NOT NULL`, la funzione ritorna `OLD` e non bumpa `updated_at`. Per fresh tombstone (`OLD.deleted_at IS NULL`, `NEW.deleted_at IS NOT NULL`) `updated_at` bumpa come normale UPDATE fisico. Il trigger anti-resurrezione esistente resta attivo. |
| **No-op update** | Un vero UPDATE fisico bumpa `updated_at`; i client devono evitare PATCH no-op se non vogliono segnalare una modifica. |
| **Rollback** | Commentato nel file: `DROP TRIGGER IF EXISTS ...` sulle tre tabelle e `DROP FUNCTION IF EXISTS public.set_inventory_catalog_updated_at()`. |
| **SQL remoto** | Non ancora eseguito in S86-B. |

**Sintesi SQL:** `CREATE OR REPLACE FUNCTION public.set_inventory_catalog_updated_at()` con `NEW.updated_at = statement_timestamp(); RETURN NEW;`, piu' tre `DROP TRIGGER IF EXISTS` / `CREATE TRIGGER ... BEFORE UPDATE ... FOR EACH ROW`.

### S86-C — Test SQL sandbox/dev `TASK086_*`

| Step | Stato | Evidenza privacy-safe |
|------|-------|-----------------------|
| **Pre-lint remoto** | ✅ ESEGUITO | `supabase db lint --linked --schema public --level warning --fail-on error` → no schema errors found. |
| **Migration apply via CLI migration** | ⚠️ PARTIAL | `supabase migration up --linked` non ha applicato nulla: la history remota contiene `20260424145010` non presente localmente. Nessuna DDL eseguita da questo comando. |
| **Migration apply SQL esplicito** | ✅ ESEGUITO | Applicato il file S86-B con `supabase db query --linked --file ...20260509120000_task086_inventory_catalog_updated_at_triggers.sql`; esito comando positivo. Nessun segreto stampato. |
| **Post-apply trigger audit** | ✅ ESEGUITO | Le tre tabelle catalogo ora hanno i trigger `trg_inventory_*_set_updated_at` oltre ai trigger tombstone `inventory_*_block_post_tombstone_update`; nessun trigger aggiunto su `inventory_product_prices`. |
| **Post-lint remoto** | ✅ ESEGUITO | `supabase db lint --linked --schema public --level warning --fail-on error` → no schema errors found. |
| **Migration history** | ⚠️ PARTIAL | La DDL e' applicata, ma `supabase migration list --linked` mostra ancora `20260509120000` non registrata nella history remota per il drift preesistente. Non ho eseguito `migration repair` per non modificare la history fuori perimetro. |

**Seed controllato usato:** `TASK086_20260509T041409Z` su linked project `jpgo...kyvm`; creati solo record fittizi prefissati: 1 supplier, 1 category, 1 product attivo, 1 product destinato a tombstone. Nessun cleanup distruttivo eseguito.

| Scenario minimo | Stato | Evidenza |
|-----------------|-------|----------|
| 1. Insert supplier/category/product `TASK086_*` | ✅ PASS | Insert: 1 supplier, 1 category, 1 product attivo, 1 product tombstone-test; `updated_at` valorizzato per supplier/category/product. |
| 2. Update normale supplier | ✅ PASS | `updated_at_advanced=true`; timestamp avanzato da `2026-05-09 04:15:05.721102+00` a `2026-05-09 04:15:19.385415+00`. |
| 3. Update normale category | ✅ PASS | `updated_at_advanced=true`; timestamp avanzato da `2026-05-09 04:15:05.721102+00` a `2026-05-09 04:15:31.835603+00`. |
| 4. Update normale product | ✅ PASS | `updated_at_advanced=true`; timestamp avanzato da `2026-05-09 04:15:05.721102+00` a `2026-05-09 04:15:41.353035+00`. |
| 5. No-op update | ✅ PASS / DOCUMENTED | `UPDATE product SET product_name = product_name` lascia il valore invariato ma bumpa `updated_at` (`updated_at_advanced=true`). Decisione: accettato come vero UPDATE fisico; raccomandazione client: evitare PATCH no-op. |
| 6. Tombstone fresh | ✅ PASS | `deleted_at` valorizzato, riga non attiva, `updated_at_advanced=true`. Semantica documentata: fresh tombstone e' una modifica di stato e bumpa `updated_at`. |
| 7. Update su riga gia' tombstoned | ✅ PASS | Tentativo di cambiare nome e `deleted_at = null`: `name_unchanged=true`, `deleted_at_unchanged=true`, `updated_at_unchanged=true`, `not_resurrected=true`. |
| 8. Due update ravvicinati | ✅ PASS | Due update supplier sequenziali hanno timestamp distinti: `2026-05-09 04:16:22.271932+00` → `2026-05-09 04:16:31.205911+00`. Precisione sufficiente nel percorso CLI/statement separati; se due UPDATE cadono nella stessa statement, non promettere monotonicita' piu' forte di `statement_timestamp()`. |
| Read-back finale `TASK086_*` | ✅ PASS | Aggregato: suppliers=1, categories=1, products=2; tutti con `updated_at` valorizzato; 1 product tombstoned. |

**Verdetto S86-C:** **PASS comportamento SQL / PARTIAL tracking migration history**.

La correzione backend e' attiva sul target dev e i test controllati `TASK086_*` passano. Residuo operativo: la migration e' in file locale e DDL applicata, ma non risulta marcata applied nella history remota a causa del drift storico `20260424145010`; serve decisione separata se si vuole normalizzare la history Supabase CLI.

### S86-D — Patch client solo se necessaria

**Verdetto:** **NO PATCH NEEDED**.

| Client | Stato | Evidenza |
|--------|-------|----------|
| **iOS DTO/select** | ✅ ESEGUITO (STATIC) | `RemoteInventorySupplierRow`, `RemoteInventoryCategoryRow`, `RemoteInventoryProductRow` decodificano `updated_at`; `SupabaseManualPushRemoteClient` seleziona `updated_at` nelle colonne supplier/category/product. |
| **iOS apply/baseline** | ✅ ESEGUITO (STATIC/UNIT) | `SupabasePullApplyService` e `SupabaseManualPushService` scrivono `remoteUpdatedAt`; baseline/preflight usano `remoteUpdatedAt`. |
| **iOS test mirati** | ✅ ESEGUITO | `xcodebuild test` su `RemoteIdentityMetadataSwiftDataTests`, `SupabasePullApplyServiceTests`, `SupabaseManualPushServiceTests`, `SupabaseCatalogBaselinePreflightIntegrationTests` → **56 test PASS** su iPhone 16e iOS 26.2. |
| **Android DTO/Room** | ✅ ESEGUITO (STATIC) | `InventorySupplierRow`, `InventoryCategoryRow`, `InventoryProductRow` decodificano `updated_at` come `updatedAt`; `SupplierRemoteRef`, `CategoryRemoteRef`, `ProductRemoteRef` hanno `remoteUpdatedAt`; Room migration 15→16 aggiunge le colonne. |
| **Android repository** | ✅ ESEGUITO (STATIC/UNIT) | `InventoryRepository` persiste `row.updatedAt` nei bridge inbound/push-applied. |
| **Android test mirati** | ✅ ESEGUITO | `JAVA_HOME=/Applications/Android Studio.app/... ./gradlew testDebugUnitTest` con test `AppDatabaseMigrationTest.migration 15 to 16 adds catalog remote updated at columns` e `DefaultInventoryRepositoryTest.021 bootstrap on empty Room with populated cloud materializes catalog prices and bridges` → **BUILD SUCCESSFUL**. Warning Gradle/AGP/Kotlin preesistenti/out-of-scope. |

Nessun file Swift/Kotlin modificato in S86-D.

### S86-E — Smoke sandbox `TASK086_*`

| Area | Stato | Evidenza privacy-safe |
|------|-------|-----------------------|
| **Supabase update/read-back** | ✅ PASS | Aggiornati supplier/category/product `TASK086_*` creati nella slice, con `WHERE` sui nomi/prefissi test. Read-back: supplier `2026-05-09 04:16:31.205911+00` → `2026-05-09 04:20:28.606175+00`; category `2026-05-09 04:15:31.835603+00` → `2026-05-09 04:20:28.606175+00`; product `2026-05-09 04:15:50.853933+00` → `2026-05-09 04:20:28.606175+00`; `changed=true` per tutte e tre. |
| **iOS read-back service-level** | ✅ PASS / STATIC+UNIT | DTO/select/apply/baseline leggono e propagano `updated_at` come `remoteUpdatedAt`; test mirati iOS S86-D PASS (56 test). Runtime app autenticata non eseguita in questa slice. |
| **Android read-back service-level** | ✅ PASS / STATIC+UNIT | DTO catalogo decodificano `updated_at`; repository persiste `remoteUpdatedAt` nei remote ref Room; test mirati Android S86-D PASS. Runtime app autenticata non eseguita in questa slice. |
| **Scenario stale iOS** | ✅ PASS / UNIT | `SupabaseManualPushPreflightTests/testRemoteUpdatedAtNewerThanLocalBlocksRemoteConflict` PASS: baseline vecchia + remoteUpdatedAt piu' nuovo blocca il push come conflitto remoto, senza sovrascrittura silenziosa. |
| **Scenario stale Android** | ⚠️ PARTIAL | Verificato staticamente che `updated_at` viene persistito in `remoteUpdatedAt`; non trovato/eseguito un runtime autenticato Android che dimostri un blocco stale completo end-to-end. |
| **Runtime iOS ↔ Supabase ↔ Android** | ⚠️ PARTIAL | Nessuna sessione app autenticata sicura e condivisa e nessun flusso UI runtime completo avviato; smoke limitato a SQL/read-back Supabase e test/service-level, come limite documentato. |

**Verdetto S86-E:** **PARTIAL**.

Motivo: il backend aggiornato produce timestamp nuovi e i due client hanno mapping/persistenza testati a livello statico/unitario. Non dichiaro PASS runtime cross-platform autenticato perché non e' stata eseguita una sessione app iOS ↔ Supabase ↔ Android completa.

### S86-F — Review/handoff execution

| Voce | Esito |
|------|-------|
| **File modificati** | `docs/MASTER-PLAN.md`; `docs/TASKS/TASK-086-supabase-updated-at-policy-catalog-ios.md`; `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260509120000_task086_inventory_catalog_updated_at_triggers.sql`. |
| **SQL creato** | Migration additiva con funzione `public.set_inventory_catalog_updated_at()` e trigger `trg_inventory_suppliers_set_updated_at`, `trg_inventory_categories_set_updated_at`, `trg_inventory_products_set_updated_at`. |
| **SQL applicato** | Applicato al linked project Supabase target via `supabase db query --linked --file ...`; non via `supabase migration up` per drift migration history preesistente. |
| **Ambiente usato** | Linked project Supabase mascherato `jpgo...kyvm`; iOS repo `/Users/minxiang/Desktop/iOSMerchandiseControl`; Android repo `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`; Supabase locale project files `/Users/minxiang/Desktop/MerchandiseControlSupabase`. |
| **Segreti** | Nessun segreto, token, anon key, service role key o connection string completa stampati/documentati. |
| **Fixture dati** | Usate solo righe fake prefissate `TASK086_*`; nessun dato reale di negozio usato come fixture. |
| **Operazioni vietate** | Nessun delete/truncate/drop/reset/cleanup distruttivo; nessun backfill massivo; nessun `UPDATE` massivo senza `WHERE`; nessun TASK-087 aperto. |
| **Risultati SQL** | `updated_at_advanced=true` per update normale supplier/category/product; no-op update bumpa per vero UPDATE fisico; fresh tombstone bumpa e non resuscita; update su tombstoned non cambia nome/deleted_at/updated_at; trigger audit e lint PASS. |
| **Risultati iOS** | 56 test mirati PASS su iPhone 16e iOS 26.2; stale preflight dedicato PASS; nessuna patch Swift necessaria. |
| **Risultati Android** | Test mirati Room/repository PASS con JBR Android Studio; `assembleDebug` PASS; warning Gradle/AGP/Kotlin preesistenti/out-of-scope; nessuna patch Kotlin TASK-086. |
| **Git / hygiene** | `git diff --check` PASS nei repo iOS e Android; Supabase project non e' una git working tree; migration SQL controllata per trailing whitespace senza warning. |
| **Stato finale TASK-086** | **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **NON DONE**. |
| **Gap residui** | Supabase migration history non registra `20260509120000` come applied per drift storico; local DB runtime non avviato; smoke runtime autenticato iOS ↔ Supabase ↔ Android non eseguito; stale Android end-to-end resta PARTIAL. |
| **Prossimo step consigliato** | Review Claude/utente su TASK-086: decidere se accettare DDL applicata + file migration con history drift documentato, oppure pianificare una normalizzazione separata della migration history; non aprire TASK-087 finché questa review non chiude l'handoff. |

**Handoff post-execution:** TASK-086 torna a **REVIEW**. Non e' marcato DONE.

## Review / Chiusura — 2026-05-09

### Verdetto review

**APPROVED** — TASK-086 chiuso come **DONE / Chiusura**.

La review conferma che il gap backend `updated_at` su UPDATE normale e' corretto in modo minimale e coerente per:

- `inventory_suppliers`;
- `inventory_categories`;
- `inventory_products`.

La chiusura non equivale a claim "production-ready 100%" e non chiude il futuro smoke runtime autenticato cross-platform.

### Review migration SQL

| Controllo | Esito review |
|----------|--------------|
| Funzione `public.set_inventory_catalog_updated_at()` | ✅ APPROVED — funzione piccola, `plpgsql`, `search_path` esplicito, nessun `SECURITY DEFINER`. |
| Clock Postgres | ✅ APPROVED — usa `statement_timestamp()` lato DB. |
| Return path | ✅ APPROVED — `RETURN NEW` su update normale; `RETURN OLD` su righe gia' tombstoned per non bumpare/resuscitare. |
| No data rewrite | ✅ APPROVED — nessun `UPDATE inventory_*` dentro trigger, nessun backfill, nessun cleanup. |
| Perimetro tabelle | ✅ APPROVED — trigger solo su suppliers/categories/products; nessun trigger su product prices, sync_events, history_entries, shared_sheet_sessions. |
| RLS/grants/unique | ✅ APPROVED — nessun cambio RLS, grants, vincoli unique o partial unique. |
| Naming | ✅ APPROVED — `trg_inventory_suppliers_set_updated_at`, `trg_inventory_categories_set_updated_at`, `trg_inventory_products_set_updated_at`. |
| Tombstone | ✅ APPROVED — compatibile con `inventory_catalog_block_update_when_tombstoned`; test review conferma riga gia' tombstoned non resuscitata. |
| Rollback | ✅ APPROVED — rollback commentato con drop dei tre trigger e drop della funzione. |

Nessun fix SQL applicato in review.

### Review Supabase execution

| Controllo | Esito review |
|----------|--------------|
| `supabase db lint` | ✅ PASS — `No schema errors found`. |
| Trigger/funzione read-back | ✅ PASS — funzione presente; tre trigger `trg_inventory_*_set_updated_at` enabled sulle sole tabelle target; trigger tombstone ancora presenti. |
| Smoke review `TASK086_*` | ✅ PASS — update controllato su righe test gia' create, con `WHERE` sui record `TASK086_*`: supplier/category/product `updated_at_advanced=true`, timestamp `2026-05-09 04:29:34.840406+00`. |
| No-op update execution | ✅ PASS / DOCUMENTED — un vero UPDATE fisico bumpa `updated_at`; i client devono evitare PATCH no-op. |
| Fresh tombstone execution | ✅ PASS / DOCUMENTED — bumpa `updated_at` e non riattiva la riga. |
| Already tombstoned execution | ✅ PASS — update su riga gia' tombstoned non cambia nome/deleted_at/updated_at. |
| Fixture | ✅ PASS — solo righe fake `TASK086_*`; nessun dato reale usato come fixture. |
| Operazioni distruttive | ✅ PASS — nessun delete/truncate/drop/reset dati, nessun cleanup, nessun backfill. |

### Decisione migration history

**Opzione A — ACCEPTED / FOLLOW-UP.**

La DDL e' applicata e il comportamento backend richiesto da TASK-086 passa in read-back e smoke SQL. Il drift della migration history e' reale e va mantenuto visibile, ma non blocca la chiusura funzionale di TASK-086 per questi motivi:

- il drift storico era preesistente alla migration TASK-086 (`20260424145010` remoto non locale; alcune migration locali non remote);
- lo schema effettivo remoto e' coerente con il perimetro TASK-086;
- la migration TASK-086 e' idempotente e additiva;
- normalizzare la history ora richiederebbe una decisione operativa separata su `supabase migration repair`, non necessaria per validare il bugfix `updated_at`.

In review non ho eseguito `migration repair` e non ho modificato `supabase_migrations.schema_migrations`.

### Review iOS

| Controllo | Esito review |
|----------|--------------|
| DTO/select | ✅ PASS — `RemoteInventorySupplierRow`, `RemoteInventoryCategoryRow`, `RemoteInventoryProductRow` decodificano `updated_at`; i select includono `updated_at`. |
| Apply/baseline | ✅ PASS — `remoteUpdatedAt` viene propagato in apply e baseline/preflight. |
| Stale preflight | ✅ PASS — `testRemoteUpdatedAtNewerThanLocalBlocksRemoteConflict` blocca il conflitto remoto. |
| Test mirati | ✅ PASS — `xcodebuild test` mirato: **57 test**, 0 failure. |
| Patch Swift/UI | ✅ NO PATCH NEEDED — nessuna nuova UI, nessun micro-copy necessario per TASK-086. |

### Review Android

| Controllo | Esito review |
|----------|--------------|
| DTO catalogo | ✅ PASS — supplier/category/product row decodificano `updated_at` come `updatedAt`. |
| Room v16 / remote refs | ✅ PASS — migration 15→16 e remote refs hanno `remoteUpdatedAt`. |
| Repository | ✅ PASS — inbound/push-applied persistono `row.updatedAt` nei remote ref. |
| Test mirati | ✅ PASS — test migration/repository mirati `BUILD SUCCESSFUL`. |
| Build | ✅ PASS — `assembleDebug` `BUILD SUCCESSFUL`. |
| Patch Kotlin | ✅ NO PATCH NEEDED — nessuna patch Android necessaria per TASK-086. |

Nota review: il flag storico Android `products_updated_at_untrusted` resta in un contratto di incremental sync non verificabile insieme a `no_realtime_inventory_publication` e `inventory_product_prices_no_updated_at`; non blocca la chiusura TASK-086 perché il path di lettura/persistenza `remoteUpdatedAt` e' valido e il runtime cross-platform resta dichiarato PARTIAL separatamente.

### Check finali review

| Check | Stato |
|-------|-------|
| Supabase lint | ✅ ESEGUITO — PASS. |
| Supabase trigger/funzione read-back | ✅ ESEGUITO — PASS. |
| Supabase smoke `TASK086_*` | ✅ ESEGUITO — PASS su supplier/category/product. |
| iOS XCTest mirati | ✅ ESEGUITO — 57 test PASS. |
| Android unit mirati | ✅ ESEGUITO — PASS. |
| Android `assembleDebug` | ✅ ESEGUITO — PASS; warning Gradle/AGP/Kotlin preesistenti/out-of-scope. |
| `git diff --check` | ✅ ESEGUITO — PASS su iOS e Android dopo review. |
| Supabase project git check | ⚠️ NON ESEGUIBILE — `/Users/minxiang/Desktop/MerchandiseControlSupabase` non e' una git working tree; migration SQL controllata via lettura/whitespace. |

### Conferme review

- Nessun segreto, token, anon key, service role key o connection string completa stampati.
- Nessun dato reale usato come fixture.
- Nessun delete/truncate/drop/reset dati.
- Nessun cleanup dei record `TASK086_*`.
- Nessun backfill.
- Nessuna normalizzazione migration history eseguita.
- Nessuna patch Swift/Kotlin/UI applicata.
- Nessun TASK-087 aperto.

### Gap residui dopo TASK-086

- Runtime autenticato iOS ↔ Supabase ↔ Android resta **PARTIAL / NOT RUN**.
- Migration history drift resta **ACCEPTED / FOLLOW-UP**.
- Local Supabase DB runtime non avviato in questa execution/review.
- Stale Android end-to-end runtime resta da provare in task separato.

### Stato conclusivo

**TASK-086 DONE / Chiusura**.
