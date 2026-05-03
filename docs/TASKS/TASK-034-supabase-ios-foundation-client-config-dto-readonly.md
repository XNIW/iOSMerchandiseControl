# TASK-034: Supabase iOS foundation — client config + DTO readonly

## Informazioni generali
- **Task ID**: TASK-034
- **Titolo**: Supabase iOS foundation: client config + DTO readonly
- **File task**: `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-03
- **Ultimo agente che ha operato**: Claude *(planning TASK-034)*

## Dipendenze
- **Dipende da**: TASK-033
- **Sblocca**: TASK-035

## Scopo
Prima integrazione codice Supabase lato iOS dopo schema audit. Solo foundation e DTO, senza sync automatico.

## Contesto
Questo task può partire solo dopo il mapping schema/model di TASK-033. Il perimetro è readonly e non introduce push o sync automatico.

## Non incluso
- Push verso Supabase
- Sync automatico
- Auth/multiutente se non richiesta
- Modifiche distruttive a SwiftData

## Scope
- Aggiungere dependency Supabase Swift
- Configurazione URL/key sicura
- DTO remoti per Product, Supplier, Category, ProductPrice
- Servizio readonly iniziale
- Nessun push
- Nessuna auth/multiutente se non richiesta

## Output richiesto
- Build verde
- Fetch remoto controllato
- Nessuna modifica distruttiva a SwiftData

## Criteri di accettazione
- [ ] Dependency e configurazione sono introdotte secondo decisioni di TASK-033
- [ ] DTO readonly compilano e mappano lo schema auditato
- [ ] Fetch remoto controllato funziona o ha blocker documentato
- [ ] Nessuna scrittura locale o remota automatica viene introdotta

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Verifica dipendenza TASK-033

- **TASK-033** risulta **DONE** (chiusura confermata nel file task; audit in `docs/SUPABASE/TASK-033-schema-audit.md`).
- Mapping schema ↔ modelli iOS/Android e sintesi tabellare (`inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, oltre ad altre tabelle di contesto) sono **sufficienti** per definire DTO e `CodingKeys` in Execution.
- **Nessun blocker** sul prerequisito “TASK-033 concluso con mapping auditato”.
- **Nota**: possibile **drift** tra migrazioni in repo e progetto hosted (già citato come gap G-08/G-09 in TASK-033): in Execution va verificato l’ambiente reale o documentato errore preciso.

---

### A. Obiettivo preciso del task

TASK-034 implementa **solo la foundation Supabase lato iOS**: dipendenza SwiftPM ufficiale, caricamento sicuro di URL/progetto/chiave, **client e servizio read-only** con DTO dedicati per il dominio inventario / catalogo remoto (prodotti, fornitori, categorie, storico prezzi), e un **fetch controllato** (manuale/diagnostico) senza scrivere SwiftData né remoto.

**Non è sync**: niente merge locale, niente allineamento periodico, niente mirror del database offline. TASK-034 non sostituisce né estende `InventorySyncService` (che resta “applicazione inventario → SwiftData”).

---

### B. Stato attuale iOS (lettura repo)

Modelli **SwiftData** registrati in `iOSMerchandiseControlApp.swift` nel `modelContainer`:

| Modello | File | Ruolo |
|--------|------|--------|
| `Supplier` | `Models.swift` | Fornitore; chiave logica `name` unica (senza `owner_user_id` / UUID remoto). |
| `ProductCategory` | `Models.swift` | Categoria; `name` unica. |
| `Product` | `Models.swift` | Prodotto; `barcode` unico globale sul device; prezzi snapshot; relazioni verso `Supplier` / `ProductCategory`; `priceHistory` a cascata. |
| `ProductPrice` | `Models.swift` | Storico prezzi; `PriceType` `.purchase` / `.retail`; `effectiveAt` / `createdAt` come `Date`. |
| `HistoryEntry` | `HistoryEntry.swift` | Sessione inventario/griglia JSON, `syncStatus`, metadati; **non** è tabella Supabase `shared_sheet_sessions` 1:1 (vedi TASK-033). |

`InventorySyncService` oggi:

- È `@MainActor`, usa **`ModelContext`** SwiftData.
- Legge la griglia da `HistoryEntry`, aggiorna `Product.stockQuantity`, opzionalmente `retailPrice`, inserisce `ProductPrice` con `source: "INVENTORY_SYNC"`, aggiorna `HistoryEntry.syncStatus` e colonna `SyncError` nella griglia.
- **Non** deve essere riusato né esteso per chiamate HTTP/Supabase: la naming “sync” è **solo sync locale inventario → DB**.

`OptionsView.swift`: solo tema e lingua (`Form` + sezioni); **nessuna** integrazione Supabase.

`project.pbxproj`: dipendenze SPM presenti **SwiftSoup**, **xlsxwriter**, **ZIPFoundation**; **nessun** pacchetto `supabase-swift` / Supabase.

---

### C. Riferimento Android (solo funzionale)

Android (Room) oggi fornisce **parità concettuale**: entità **Product**, **Supplier**, **Category**, **ProductPrice** (tipo stringa PURCHASE/RETAIL, timestamp storico come stringa canonica), **storico prezzi** e view tipo summary, **repository** locale + bridge remoto (`*RemoteRef*`, orchestrazione verso Supabase) già presenti nel progetto Android.

Per TASK-034:

- Usare Android solo per **allineare semantica** (es. tipi prezzo maiuscoli, formato testo `effective_at` / `created_at` sul cloud) come già documentato in TASK-033.
- **Non** portare pattern Kotlin/Room/Repository Android in Swift 1:1; i DTO iOS sono struct `Codable` isolate da SwiftData.

---

### D. Riferimento Supabase usato (fonti lette; niente colonne inventate)

**Fonte di verità schema**: `docs/SUPABASE/TASK-033-schema-audit.md` (prodotto da TASK-033), integrata da lettura diretta delle migrazioni sotto `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/`:

| File migrazione (repo locale) | Contenuto rilevante per TASK-034 |
|------------------------------|-----------------------------------|
| `20260416_task010_shared_sheet_sessions_realtime.sql` | `shared_sheet_sessions` (fuori perimetro DTO catalogo TASK-034). |
| `20260417_task012_ownership_rls.sql` | Ownership `owner_user_id`, policy solo owner, revoche `anon`. |
| `20260417120000_task013_inventory_catalog_rls.sql` | DDL `inventory_suppliers`, `inventory_categories`, `inventory_products`; **RLS** `auth.uid() = owner_user_id`; `REVOKE ALL` su **`anon`** e **`authenticated`** poi `GRANT` selettivi su **`authenticated`**; policy SELECT/INSERT/UPDATE/DELETE per owner. |
| `20260417200000_task016_inventory_product_prices.sql` | DDL `inventory_product_prices`; CHECK `type IN ('PURCHASE','RETAIL')`; `effective_at` / `created_at` **text**; stesso modello GRANT/RLS (`authenticated` owner-scoped). |
| `20260418200000_task019_inventory_catalog_tombstone.sql` | `deleted_at` catalogo, trigger tombstone, indici unici parziali. |
| `20260421120000_task038_restrict_authenticated_delete_inventory.sql` | Restrizioni DELETE (revoche/policy) su catalogo e prezzi — rilevante per futuri task write, non per read-only SELECT. |
| `20260422120000_task040_shared_sheet_sessions_v2.sql` | Evoluzione sessioni (fuori perimetro TASK-034). |
| `20260424021936_task045_sync_events.sql` | `sync_events`, RPC `record_sync_event` (fuori perimetro fetch catalogo readonly TASK-034). |

Policy/grant: **non** esiste cartella `policies/` separata; RLS e `GRANT`/`REVOKE` sono **nelle migrazioni SQL** sopra.

**Controllo critico Data API / PostgREST (blocco operativo se ignorato)**:

- Le tabelle `inventory_*` sono esposte a **PostgREST** solo nei limiti dei **privilegi ruolo** + **RLS**.
- Dal DDL in **013/016**: `anon` ha **`REVOKE ALL`** sulle tabelle catalogo/prezzi; le policy SELECT sono per ruolo **`authenticated`** con **`auth.uid() = owner_user_id`**.
- Quindi: una **read API** con **sola “anon key”** e **nessun JWT utente** che assuma il ruolo `authenticated` **non potrà** leggere `inventory_products` ecc., salvo diverso schema su ambiente hosted (da verificare). Il fetch controllato in TASK-034 deve **o** usare **sessione Supabase Auth** (JWT) coerente con RLS, **o** documentare **blocker** con errore reale (tipicamente vuoto/401/403 da PostgREST) e la strategia di sblocco (auth minima, oppure allineamento progetto — fuori scope se non richiesto).
- **Mai** usare `service_role` nell’app client: bypass RLS e viola il requisito di sicurezza.

*Supabase repo locale*: accessibile; *seed / `.env.example`*: assenti o non usati in audit TASK-033.

---

### E. Decisioni architetturali

1. **Dipendenza**: aggiungere **`supabase-swift`** via **Swift Package Manager** (prodotto ufficiale Supabase per Apple), collegando il target app in Xcode / `project.pbxproj`. Motivo: **Auth + PostgREST** in un solo stack, utile quando si introduce JWT; evita duplicare header e URL base.
2. **Alternativa scartata per default**: solo `URLSession` + REST manuale — possibile ma più fragile (auth, tipi, paging); si può citare solo come fallback documentato se SPM fallisce per deployment target.
3. **Chiavi**: usare **URL progetto** + chiave **publishable/anon** dal pannello Supabase **nell’app**; **mai** `service_role`. Se serve leggere dati RLS-protetti, la chiave anon è corretta **come client** ma occorre **login/signIn** che emetta JWT `authenticated` (vedi §D).
4. **Segreti**: nessun segreto reale in git; file esempio senza valori sensibili (`SupabaseConfig.example.plist` o chiavi placeholder in template); file reale `SupabaseConfig.plist` (o inclusione via **.xcconfig** locale non tracciato) in `.gitignore` se necessario.
5. **Config loader**: tipo dedicato (es. `SupabaseConfig` struct) che legge plist/xcconfig, **fallisce in modo non fatal** per l’app: assenza config ⇒ nessun client, nessun crash all’avvio (vedi criteri §J).
6. **DTO**: struct Swift **`Codable`** distinte da `@Model` SwiftData; `CodingKeys` per **snake_case** DB (`owner_user_id`, `product_name`, `supplier_id`, `effective_at`, …).
7. **`SupabaseInventoryService` (readonly)**: incapsula solo operazioni **GET/list** (o `.select().limit()`); **nessun** `ModelContext`; **nessun** `insert`/`update`/`upsert`/`delete` remoto; **nessuna** scrittura SwiftData automatica dai risultati remoti.
8. **Contesto auth**: se il perimetro task resta “senza multiutente/login UX”, valutare in Execution: **una** sessione di test (es. email/password dev solo build Debug) **nascosta** dietro flag, oppure documentare fetch non verificabile finché Auth non è definita — **senza** ampliare a product feature auth completa.

---

### F. File iOS probabilmente da toccare in Execution futura *(solo elenco; nessuna modifica in Planning)*

- `iOSMerchandiseControl.xcodeproj/project.pbxproj` — riferimento pacchetto SPM Supabase + eventualmente file risorse plist esclusi da sync git se applicabile.
- `iOSMerchandiseControl/SupabaseConfig.swift` *(nuovo)* — loader configurazione, validazione URL/key.
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift` *(nuovo)* — DTO per righe `inventory_products`, `inventory_suppliers`, `inventory_categories`, `inventory_product_prices` allineati a TASK-033.
- `iOSMerchandiseControl/SupabaseInventoryService.swift` *(nuovo)* — client read-only; metodi espliciti tipo “fetch N prodotti” / “fetch prezzi per product_id” per test.
- `iOSMerchandiseControl/OptionsView.swift` — **solo se** serve UI minima di test connessione (vedi §H).
- `iOSMerchandiseControl/SupabaseConfig.example.plist` *(nuovo, tracciato)* — template senza segreti.
- `.gitignore` — escludere `SupabaseConfig.plist` reale o `*.xcconfig` locali con segreti, se adottati.

**Non** modificare in TASK-034: `Models.swift`, `HistoryEntry.swift`, `InventorySyncService.swift` (logica sync locale), né schema SwiftData / `modelContainer`.

---

### G. Piano step-by-step per la futura Execution (ordine minimo)

1. Aggiungere dipendenza **Supabase Swift** (SPM) e verificare **deployment target** iOS compatibile con la versione pacchetto scelta.
2. Aggiungere **config loader robusto** + file esempio; documentare dove l’utente inserisce URL/key reali fuori da git.
3. Implementare **DTO readonly** con `CodingKeys` coerenti con colonne audit TASK-033 (inclusi `deleted_at` su catalogo se presente nelle SELECT).
4. Implementare **`SupabaseInventoryService`**: inizializzazione client opzionale; metodi di fetch; gestione errori tipizzata; vincolo esplicito **no write API**.
5. **Test manuale/diagnostico**: azione utente che esegue **un** fetch limitato (es. `limit(5)`) e mostra esito (vedi §H); log solo non sensibile.
6. **Build** Release/Debug; zero crash se config assente.
7. **Documentare in Execution/Handoff**: esito fetch reale **oppure** blocker (messaggio PostgREST/RLS, auth mancante, drift schema).

---

### H. UX/UI

Se si include il test connessione:

- **OptionsView**: nuova **Section** nativa (Form) con titolo chiaro (es. diagnosi Supabase / sviluppo).
- Controlli: pulsante **“Test connessione Supabase”**; **`ProgressView`** durante la richiesta; esito con **`Label`** o **`alert`** (successo con conteggio righe / errore leggibile).
- **Niente** nuove tab, flussi complessi o schermate dedicate oltre questa sezione — resto app invariato.

---

### I. Rischi e mitigazioni

| Rischio | Mitigazione |
|--------|-------------|
| Schema hosted ≠ mapping TASK-033 | Confronto una tantum in Execution; adeguare DTO o documentare drift (G-08). |
| Date: ISO8601 vs `timestamptz` vs **text** `yyyy-MM-dd HH:mm:ss` su prezzi | DTO con `String` per colonne text auditate; parser dedicato in futuro TASK-035; no conversione silenziosa errata. |
| **snake_case** vs proprietà Swift | Solo `CodingKeys`; evitare `convertFromSnakeCase` globale se conflitti. |
| **ProductCategory** iOS vs tabella **`inventory_categories`** remota | DTO nome esplicito tipo `RemoteInventoryCategoryRow`; nessun rename del model SwiftData. |
| **Permission denied** (RLS, grant `anon`, JWT assente) | Testare con sessione autenticata; se task vieta auth, documentare blocker §D. |
| Config mancata / plist non nel bundle | Loader opzionale; feature disabilitata; messaggio UI chiaro. |
| Pacchetto Supabase richiede iOS più alto del target attuale | Verificare versione SPM vs `IPHONEOS_DEPLOYMENT_TARGET` prima di merge. |
| Slittamento involontario verso “sync” | Code review: vietare `import SwiftData` nel servizio Supabase; vietare `ModelContext` nei file Supabase*. |

---

### J. Criteri di accettazione raffinati (contratto Execution/Review)

- [ ] **Build** verde (target app principale).
- [ ] Con **config Supabase assente** o invalida, l’app **non crasha**; il percorso diagnostico è disabilitato o segnala errore controllato.
- [ ] I **DTO** compilano e riflettono lo schema **auditato** in TASK-033 per le quattro entità remote (prodotti, fornitori, categorie, storico prezzi).
- [ ] **Fetch read-only controllato** restituisce dati attesi **oppure** è documentato un **blocker** con errore API/Postgres/RLS **preciso** (codice/messaggio) e causa nota.
- [ ] **Nessuna** operazione remota di `insert` / `update` / `upsert` / `delete` nel codice aggiunto.
- [ ] **Nessuna** scrittura **SwiftData** automatica o merge da fetch TASK-034.
- [ ] **Nessuna** feature auth/multiutente o schermata login **di prodotto** introdotta, salvo **override** documentato in Decisioni se serve solo JWT tecnico dev.
- [ ] **Nessuna** modifica distruttiva a `modelContainer`, modelli `@Model`, o migration SwiftData.

---

### K. Cosa NON fare (perimetro esplicito)

- Non implementare **sync** bidirezionale, né job periodici, né “allinea tutto”.
- Non fare **push** verso Supabase da TASK-034.
- Non introdurre **login utente** / onboarding multi-account **come feature** senza rescoping formale.
- Non alterare **`Product`**, **`Supplier`**, **`ProductCategory`**, **`ProductPrice`**, **`HistoryEntry`** SwiftData per adattarli al JSON Supabase.
- Non **persistere** risultati remoti nel database locale.
- Non incorporare **`service_role`** o altre chiavi server-only nell’app.
- Non fare **refactor UI** ampio (es. ridisegno Options) oltre la piccola Section opzionale §H.

---

### Handoff (post-approvazione planning → Execution)

- **Prossima fase**: EXECUTION  
- **Prossimo agente**: CODEX  
- **Azione consigliata**: confermare con il committente/policy se il fetch readonly deve supportare **solo ambiente senza auth** (probabilmente **fallirà** sullo schema in repo) o se è accettabile **JWT dev minimo**; poi eseguire gli step in §G nell’ordine indicato, aggiornando solo le sezioni Execution/Handoff del presente file.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
Non avviata.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
Non avviata.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
—

### Riepilogo finale
—

### Data completamento

