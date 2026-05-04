# TASK-034: Supabase iOS foundation — client config + DTO readonly

## Informazioni generali
- **Task ID**: TASK-034
- **Titolo**: Supabase iOS foundation: client config + DTO readonly
- **File task**: `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
- **Stato**: DONE
- **Fase attuale**: DONE
- **Responsabile attuale**: Review / Claude — completed
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-04
- **Ultimo agente che ha operato**: Claude / Review — approved TASK-034 and closed task

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
- **Fetch remoto controllato** (catalog probe read-only) **oppure** **blocker RLS/auth documentato con errore preciso** — **quest’ultimo non costituisce fallimento del task** se il catalogo `inventory_*` non è leggibile con sola chiave publishable/anon (vedi §D, §E.3)
- Nessuna modifica distruttiva a SwiftData

## Criteri di accettazione
- [x] Dependency e configurazione sono introdotte secondo decisioni di TASK-033
- [x] DTO readonly compilano e mappano lo schema auditato
- [x] **Fetch remoto controllato** restituisce dati attesi dal catalogo **oppure** è documentato un **blocker RLS/auth** (o altro) con errore preciso — **senza** interpretare il solo esito “catalogo non leggibile con anon key” come task fallito
- [x] Nessuna scrittura locale o remota automatica viene introdotta

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Verifica dipendenza TASK-033

- **TASK-033** risulta **DONE** (chiusura confermata nel file task; audit in `docs/SUPABASE/TASK-033-schema-audit.md`).
- Mapping schema ↔ modelli iOS/Android e sintesi tabellare (`inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, oltre ad altre tabelle di contesto) sono **sufficienti** per definire DTO e `CodingKeys` in Execution.
- **Nessun blocker** sul prerequisito “TASK-033 concluso con mapping auditato”.
- **Nota**: possibile **drift** tra migrazioni in repo e progetto hosted (già citato come gap G-08/G-09 in TASK-033): in Execution va verificato l’ambiente reale o documentato errore preciso.

---

### A. Obiettivo preciso del task

TASK-034 implementa **solo la foundation Supabase lato iOS**: dipendenza SwiftPM ufficiale, caricamento sicuro di URL/progetto/chiave, **client e servizio read-only** con DTO dedicati per il dominio inventario / catalogo remoto (prodotti, fornitori, categorie, storico prezzi), e un **catalog probe** diagnostico (lettura controllata remota) senza scrivere SwiftData né remoto.

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
- **Decisione TASK-034 (vedi §E — Auth)**: il client foundation usa **solo publishable/anon key**; **nessun** JWT persistito, **nessun** login UI, **nessuna** credenziale dev. Se con tale configurazione il fetch su `inventory_*` fallisce per ruolo/RLS, **non** è un fallimento del task foundation: è un **blocker previsto** — da **mostrare in UI diagnostica** (messaggio leggibile) e **registrare in Execution/Handoff** con **errore preciso** (codice HTTP PostgREST, corpo messaggio, hint `permissionDeniedOrRLS` o equivalente). La **vera autenticazione utente** e l’eventuale sessione `authenticated` vanno **pianificate in un TASK successivo dedicato**, non in TASK-034.
- **Mai** usare `service_role` nel client iOS: bypass RLS e viola il requisito di sicurezza.

*Supabase repo locale*: accessibile; *seed / `.env.example`*: assenti o non usati in audit TASK-033.

---

### E. Decisioni architetturali

#### E.1 Package Supabase Swift

- Aggiungere **`supabase-swift`** tramite **Swift Package Manager**; **collegare il prodotto `Supabase`** (o il product name effettivo esposto dal pacchetto alla versione scelta) al **target app principale** `iOSMerchandiseControl`, **non** limitarlo al solo target test.
- Verificare **compatibilità con `IPHONEOS_DEPLOYMENT_TARGET`** attuale prima di consolidare la versione SPM.
- **Preferire** il repository/major version **ufficiale e aggiornato** indicato nella documentazione Supabase per Swift (Apple).
- Se la **URL del package** o il **branch/version** nelle guide (docs vs quickstart) **differiscono**, in Execution documentare nel file task **quale URL/versione è stata effettivamente aggiunta in Xcode** e **perché** (es. allineamento a doc ufficiale, vincolo Xcode, pin di sicurezza).
- **Alternativa scartata per default**: solo `URLSession` + REST manuale — possibile solo come fallback **documentato** se SPM/deployment target bloccano.

#### E.2 Sicurezza chiavi, segreti e logging

- Usare la **publishable key** (nuova denominazione Supabase) quando il progetto la espone; usare la **anon / legacy anon** solo se il progetto hosted è ancora su modello legacy — in ogni caso **solo** chiave **pubblica** idonea al client, **mai** `service_role`, **mai** **secret key** nell’app iOS.
- **Non loggare mai**: chiavi API, **URL completi con token/query segrete**, header **`Authorization`**, corpi di **JWT** (nè in `print`/OSLog crash-ready).
- `SupabaseConfig.example.plist` (tracciato): **solo placeholder** testuali tipo `YOUR_PROJECT_URL`, `YOUR_ANON_OR_PUBLISHABLE_KEY`.
- `SupabaseConfig.plist` **reale**: **escluso da git** (`.gitignore`); stesso trattamento per **`.xcconfig` locale** con URL/key reali.
- **Config loader**: tipo dedicato (es. struct `SupabaseConfig`) che legge plist/xcconfig; **assenza o invalidità** ⇒ niente client, **nessun crash** all’avvio (vedi §J).

#### E.3 Auth — decisione definitiva per TASK-034

- **Non** si introduce **login UI** né schermata **auth** per l’utente finale.
- **Non** si introducono **email/password dev hardcoded** nell’app.
- **Non** si salva un **JWT manuale** (incollato, file locale committato, UserDefaults “temporaneo” per aggirare RLS).
- **Non** si introduce **multiutente** / gestione account.
- Il **servizio Supabase** in TASK-034 deve funzionare come **client readonly** inizializzato con **project URL + publishable/anon key** secondo policy §E.2.
- **Motivazione**: lo schema **auditato** in TASK-033 applica **`REVOKE ALL` su `anon`** per `inventory_*` e policy **owner-scoped** con **`auth.uid()`** per il ruolo **`authenticated`**. Con **sola chiave pubblica** e **nessuna sessione** `authenticated`, il **fetch** sul catalogo remoto **può fallire** (es. lista vuota con 200, **401/403**, o messaggio RLS). Questo è un **esito atteso e accettabile** nel perimetro TASK-034: va **trattato come blocker documentato** (errore distinguibile, UI leggibile, nessun crash), **non** come fallimento del “foundation layer”. La **progettazione e l’implementazione dell’autenticazione reale** (sessione JWT, sign-in, ecc.) è **fuori da TASK-034** e va affidata a **TASK dedicato** successivo.

#### E.4 DTO remoti (naming e vincoli)

- Nomi espliciti **`Remote…Row`**, allineati al dominio remoto, es.:
  `RemoteInventoryProductRow`, `RemoteInventorySupplierRow`, `RemoteInventoryCategoryRow`, `RemoteInventoryProductPriceRow`.
- **Nessun** attributo **`@Model`**; **nessun** `import SwiftData` nei file DTO.
- `effective_at` e `created_at` su **`inventory_product_prices`**: restano **`String`** nel DTO se nello schema auditato sono **text** (TASK-033); nessun obbligo di parsing `Date` in TASK-034.
- `deleted_at` sul catalogo: includere nel DTO **solo se** la colonna è presente nello schema auditato; tipo **`String?`** (ISO da `timestamptz`) o altro tipo **coerente col JSON PostgREST** restituito — da confermare in Execution con risposta reale; **non inventare** colonne non in audit.
- Campo **`type`** remoto storico prezzi: mantenere **`String`** con valori **`"PURCHASE"`** / **`"RETAIL"`** come da CHECK SQL; **non** convertire in **`PriceType`** SwiftData locale in TASK-034 (mapping a dominio locale = task successivo / merge).

#### E.5 `SupabaseInventoryService` (readonly)

- **Nessun** `import SwiftData`; **nessun** parametro **`ModelContext`** o riferimento al model container.
- **Concurrency Swift**: metodi di rete **`async throws`**; il servizio **non** è annotato **`@MainActor`**; **vietato** eseguire lavoro di rete / await delle risposte Supabase **sul MainActor** (usare contesto non-UI o `Task` che chiama il servizio senza bloccare UI). **`OptionsView`** (o altra view diagnostica) aggiorna **loading / risultato / errori** sul **MainActor** dopo aver ricevuto l’esito dalla task asincrona.
- Esporre **solo** API di lettura indicative: `testConnection`, `fetchProducts`, `fetchSuppliers`, `fetchCategories`, `fetchProductPrices` (firme e `limit`/filtri da definire in Execution; tutte **SELECT**); implementazione concreta può spezzare internamente **config validata**, **reachability/project check** e **catalog probe** (vedi §H) pur restando dietro API pubbliche pulite.
- **Vietati** nomi di API che suggeriscano scrittura o sync: niente `save`, `sync`, `upsert`, `apply`, `merge`, `push`, `delete`, `mutate`, ecc.
- Errori: **`enum` dedicato** o errori tipizzati equivalenti, coerenti con:
  `configMissing`, `invalidConfig`, `networkError`, `permissionDeniedOrRLS`, `decodingError`, `schemaDrift`, `unknown`.

---

### F. File iOS probabilmente da toccare in Execution futura *(solo elenco; nessuna modifica in Planning)*

- `iOSMerchandiseControl.xcodeproj/project.pbxproj` — riferimento pacchetto SPM Supabase + eventualmente file risorse plist esclusi da sync git se applicabile.
- `iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — **se** Xcode/SPM lo rigenera o modifica al risolvere le dipendenze, includerlo nel commit **solo se effettivamente cambiato** da Xcode (pin versioni SPM).
- `iOSMerchandiseControl/SupabaseConfig.swift` *(nuovo)* — loader configurazione, validazione URL/key.
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift` *(nuovo)* — struct `RemoteInventoryProductRow`, `RemoteInventorySupplierRow`, `RemoteInventoryCategoryRow`, `RemoteInventoryProductPriceRow` (vedi §E.4); allineati a TASK-033; **nessun** SwiftData.
- `iOSMerchandiseControl/SupabaseInventoryService.swift` *(nuovo)* — API §E.5 (`testConnection`, `fetch*`); **nessun** SwiftData.
- `iOSMerchandiseControl/OptionsView.swift` — **solo se** serve UI minima di test connessione (vedi §H).
- `iOSMerchandiseControl/SupabaseConfig.example.plist` *(nuovo, tracciato)* — template senza segreti.
- `.gitignore` — escludere `SupabaseConfig.plist` reale o `*.xcconfig` locali con segreti, se adottati.

**Nota naming file Swift**: conviene prefisso/pattern `Supabase*` solo per config + service + DTO; **nessun** `import SwiftData` in questi file (criterio review §J).

**Non** modificare in TASK-034: `Models.swift`, `HistoryEntry.swift`, `InventorySyncService.swift` (logica sync locale), né schema SwiftData / `modelContainer`.

---

### G. Piano step-by-step per la futura Execution (ordine minimo)

1. **Swift Package Manager — `supabase-swift`**: aggiungere il package secondo documentazione ufficiale Supabase (Swift); selezionare il **prodotto libreria `Supabase`** (o equivalente nella versione scelta) e **attaccarlo al target applicativo principale** `iOSMerchandiseControl` — **verificare esplicitamente** che **non** sia linkato **solo** a `iOSMerchandiseControlTests`. Controllare **deployment target** iOS del progetto vs requisiti minimi del package; aggiornare target solo se necessario e documentato. Se l’**URL SPM** o il **pin versione** **differiscono** tra quickstart e reference principale, **annotare in Execution** URL + versione effettive e motivazione.
2. Aggiungere **config loader robusto** + file esempio; documentare dove l’utente inserisce URL/key reali fuori da git.
3. Implementare **DTO readonly** §E.4 (`RemoteInventory*Row`) con `CodingKeys` coerenti con colonne audit TASK-033 (inclusi `deleted_at` su catalogo se presente nello schema auditato).
4. Implementare **`SupabaseInventoryService`** (§E.5): inizializzazione client opzionale; `testConnection` / `fetchProducts` / `fetchSuppliers` / `fetchCategories` / `fetchProductPrices`; tassonomia errori §E.5; vincolo **no write API** / nessun nome pericoloso (§E.5).
5. **Test manuale/diagnostico** (vedi §H): un solo bottone in UI può innescare la sequenza, ma il **risultato** deve distinguere **config**, **rete/reachability**, **decoding/drift** e **catalog probe** (RLS/auth → `permissionDeniedOrRLS`). Log solo non sensibile.
6. **Build** Release/Debug; zero crash se config assente.
7. **Documentare in Execution/Handoff**: esito **catalog probe** (dati letti) **oppure** **blocker** classificato (RLS/auth, rete, config, decoding/schema drift) con messaggio preciso — **senza** trattare il solo mancato accesso `inventory_*` con anon key come fallimento del foundation task.

---

### H. UX/UI

Se si include il test connessione / fetch diagnostico:

- **Visibilità**: la sezione (es. “Test connessione Supabase” / diagnostica backend) deve essere **preferibilmente mostrata solo in build `DEBUG`** o **Development** (o dietro flag chiaro), **oppure** almeno **etichettata esplicitamente** come **diagnostica / sviluppo**, così da **non** apparire come funzione finale per il negozio.
- **Diagnostica a fasi (anche con un solo pulsante)**: il flusso deve distinguere chiaramente:
  1. **Config / client init**: URL e chiave presenti e **validi sintatticamente**; client Supabase **costruibile** (es. `configMissing` / `invalidConfig` se prima ancora della rete).
  2. **Rete / progetto raggiungibile**: fallimenti **trasporto** o endpoint irraggiungibile vs Supabase → classificazione **`networkError`** (o distinzione ulteriore documentata in Execution, senza nuovi nomi “pericolosi”).
  3. **Catalog probe**: **SELECT** limitato su `inventory_products` (o altra tabella `inventory_*` coerente con TASK-033) per verificare lettura dati reale; fallimento per **RLS / ruolo** → **`permissionDeniedOrRLS`**, **senza** confonderlo con errori di config o rete.
- L’**esito mostrato** all’utente deve rendere palese se il problema è: **config assente/invalida**, **rete**, **decoding / schema drift**, oppure **RLS/auth** — non un unico messaggio generico opaco.
- **Localizzazione**: ogni stringa **visibile** nella sezione diagnostica (titoli sezione, footer, etichette bottone, messaggi di esito/alert) deve passare dal **meccanismo di localizzazione** esistente nell’app (`L("…")` / cataloghi **strings** / nuove chiavi **localizzabili**); **vietate** stringhe SwiftUI **hardcoded** nella UI di quella sezione, **anche** se è solo Debug/Development. Coerenza con **tema** e **lingua** già gestiti in Opzioni.
- **OptionsView**: stile **nativo coerente** con l’esistente — `Form`, **`SectionHeader`** (o header/footer equivalenti al pattern attuale), **`Label`**, **`ProgressView`** durante la richiesta, esito tramite **`alert`** o messaggio testuale inline **semplice** (niente “feature” promossa).
- Controlli: pulsante la cui etichetta **localizzata** indica test/diagnostica Supabase (non testo fisso non localizzato).
- **Nessuna** nuova schermata dedicata (NavigationLink verso vista nuova, ecc.); **nessun** refactor estetico ampio di Options o del tab Opzioni.

---

### I. Rischi e mitigazioni

| Rischio | Mitigazione |
|--------|-------------|
| Schema hosted ≠ mapping TASK-033 | Confronto una tantum in Execution; adeguare DTO o documentare drift (G-08). |
| Date: ISO8601 vs `timestamptz` vs **text** `yyyy-MM-dd HH:mm:ss` su prezzi | DTO con `String` per colonne text auditate; parser dedicato in futuro TASK-035; no conversione silenziosa errata. |
| **snake_case** vs proprietà Swift | Solo `CodingKeys`; evitare `convertFromSnakeCase` globale se conflitti. |
| **ProductCategory** iOS vs tabella **`inventory_categories`** remota | DTO nome esplicito tipo `RemoteInventoryCategoryRow`; nessun rename del model SwiftData. |
| **Permission denied** (RLS, solo anon key vs policy `authenticated`) | Comportamento atteso possibile: mappare a `permissionDeniedOrRLS`; messaggio UI leggibile; **nessun** workaround JWT/login in TASK-034 (§E.3); sblocco in **TASK auth dedicato**. |
| Config mancata / plist non nel bundle | Loader opzionale; feature disabilitata; messaggio UI chiaro. |
| Pacchetto Supabase richiede iOS più alto del target attuale | Verificare versione SPM vs `IPHONEOS_DEPLOYMENT_TARGET` prima di merge. |
| Slittamento involontario verso “sync” | Code review: vietare `import SwiftData` nel servizio Supabase; vietare `ModelContext` nei file Supabase*. |

---

### J. Criteri di accettazione raffinati (contratto Execution/Review)

- [ ] **Build** verde (target app principale).
- [ ] Con **config Supabase assente** o invalida, l’app **non crasha**; il percorso diagnostico è disabilitato o segnala errore controllato.
- [ ] I **DTO** compilano e riflettono lo schema **auditato** in TASK-033 per le quattro entità remote (prodotti, fornitori, categorie, storico prezzi).
- [ ] **Fetch read-only controllato** (**catalog probe**) restituisce dati attesi **oppure** è documentato un **blocker** (incluso RLS/auth) con errore **preciso** (codice/messaggio) e causa nota; **non** si considera il task mancato se il catalogo non è leggibile **solo** con publishable/anon key (allineato §E.3 e Output richiesto).
- [ ] **Nessuna** operazione remota di `insert` / `update` / `upsert` / `delete` nel codice aggiunto.
- [ ] **Nessuna** scrittura **SwiftData** automatica o merge da fetch TASK-034.
- [ ] **Nessuna** UI **auth** / **login** / multiutente introdotta (allineato §E.3).
- [ ] **Nessuna** modifica distruttiva a `modelContainer`, modelli `@Model`, o migration SwiftData.
- [ ] Con **RLS / mancanza di ruolo `authenticated`**, il **test diagnostico** mostra un **blocker leggibile** (es. permesso negato / catalogo non leggibile con sola chiave pubblica), **l’app non crasha**.
- [ ] **Nessun** file tracciato da git contiene **segreti reali** (solo placeholder in example; plist/xcconfig reali esclusi).
- [ ] **Nessun** `import SwiftData` nei file **`Supabase*.swift`** (config, DTO, service) aggiunti per questo task.
- [ ] La **sezione diagnostica** non altera l’**UX principale** di Opzioni (tema/lingua restano prioritari; diagnostica secondaria / dev-only).
- [ ] **Stringhe diagnostiche**: tutte **localizzate** (nessun testo utente hardcoded in SwiftUI per quella sezione).

---

### K. Cosa NON fare (perimetro esplicito)

- Non implementare **sync** bidirezionale, né job periodici, né “allinea tutto”.
- Non fare **push** verso Supabase da TASK-034.
- Non introdurre **login utente**, **UI auth**, **credenziali dev hardcoded**, **JWT salvati manualmente**, né onboarding multi-account.
- Non alterare **`Product`**, **`Supplier`**, **`ProductCategory`**, **`ProductPrice`**, **`HistoryEntry`** SwiftData per adattarli al JSON Supabase.
- Non **persistere** risultati remoti nel database locale.
- Non incorporare **`service_role`** o altre chiavi server-only nell’app.
- Non fare **refactor UI** ampio (es. ridisegno Options) oltre la piccola Section opzionale §H.

---

### Handoff (stato: Planning refinement — Execution non autorizzata)

- **Questo refinement (e qualunque aggiornamento testuale al Planning) non autorizza l’Execution**: non costituisce ordine di lavoro a Codex né approvazione implicita a modificare sorgenti / Xcode / SPM.
- **Prossima fase**: **PLANNING REFINEMENT** / **attesa conferma esplicita dell’utente** prima di qualsiasi implementazione. Il task resta **ACTIVE**, **fase PLANNING**; sezione **Execution (Codex) — non avviata**.
- **Divieto assoluto finché l’utente non dice esplicitamente di procedere**: **nessun agente esecutore** (Codex o altro) deve **iniziare Execution**, modificare **codice app**, **file Swift**, **`project.pbxproj`**, **SPM**, o **installare dependency**. **Cursor / Claude** deve limitarsi ad **aggiornare solo Planning / markdown** (o altre sezioni documentali del task che non siano Execution), **senza** avvio implementativo.
- **Codex / Execution** resta **bloccato** fino a **OK esplicito dell’utente** (es. frase chiara del tipo: procedi con Execution / passa a EXECUTION) e fino ad **aggiornamento formale** di **fase → EXECUTION** + handoff operativo verso l’esecutore (nel file task e, se applicabile, nel MASTER-PLAN).
- **Nota**: il planning già incorpora la decisione **auth** (§E.3): foundation con **solo publishable/anon key**; **blocker RLS** ammesso e documentabile — **non** richiede chiusura planning per “sblocco JWT” dentro TASK-034.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
### Avvio Execution — 2026-05-03

- Task letto integralmente.
- Prontezza Execution confermata: scopo, criteri di accettazione e handoff operativo sono presenti; autorizzazione esplicita dell'utente ricevuta in chat.
- Metadata aggiornata a `Fase attuale: EXECUTION`, `Responsabile attuale: CODEX`, `Ultimo aggiornamento: 2026-05-03`, `Ultimo agente che ha operato: Cursor/Codex execution TASK-034`.
- Prossimo passo: leggere fonti richieste (MASTER-PLAN, TASK-033/audit Supabase, codice iOS rilevante) prima di modificare codice.

### Execution completata — 2026-05-03

#### Obiettivo compreso

Implementata la foundation Supabase iOS **read-only** pianificata per TASK-034: dependency Supabase Swift, configurazione locale sicura, DTO remoti separati da SwiftData, servizio di lettura iniziale e diagnostica minima DEBUG in `OptionsView`. Nessun push, sync automatico, auth/login, JWT manuale, `service_role`, scrittura SwiftData o modifica distruttiva ai modelli.

#### Fonti lette / verificate

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md` (letto integralmente)
- `docs/TASKS/TASK-033-supabase-schema-audit-ios-android-model-mapping.md`
- `docs/SUPABASE/TASK-033-schema-audit.md`
- Migrazioni Supabase locali:
  - `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260417120000_task013_inventory_catalog_rls.sql`
  - `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260417200000_task016_inventory_product_prices.sql`
  - `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260418200000_task019_inventory_catalog_tombstone.sql`
- Codice iOS rilevante:
  - `iOSMerchandiseControl.xcodeproj/project.pbxproj`
  - `iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/LocalizationManager.swift`
  - `iOSMerchandiseControl/Models.swift`
  - `iOSMerchandiseControl/InventorySyncService.swift`
  - `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
  - localizzazioni `it/en/es/zh-Hans`

#### File modificati

- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
- `iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `.gitignore` *(nuovo)*
- `iOSMerchandiseControl/SupabaseConfig.swift` *(nuovo)*
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift` *(nuovo)*
- `iOSMerchandiseControl/SupabaseInventoryService.swift` *(nuovo)*
- `iOSMerchandiseControl/SupabaseConfig.example.plist` *(nuovo, solo placeholder)*
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`

Nota tracking: nel file task sono stati rimossi anche due trailing whitespace nella sezione Planning, trattati come refusi evidenti. Nessuna riscrittura sostanziale della Planning da parte di Codex.

#### Dependency Supabase

- Package aggiunto: `https://github.com/supabase/supabase-swift.git`
- Prodotto collegato: `Supabase`
- Target collegato: target app principale `iOSMerchandiseControl`; il target `iOSMerchandiseControlTests` non ha package product dependencies Supabase.
- Versione risolta da SPM/Xcode: `2.46.0`
- Revision risolta: `dd29b624b9ceea87612d0b00457e1400f7d22c2e`
- Deployment target app corrente: `IPHONEOS_DEPLOYMENT_TARGET = 26.1`; compatibile con i requisiti minimi dichiarati dal package (iOS 13+ nel repo/documentazione Supabase).
- Motivazione URL/versione: usato il repository ufficiale `supabase/supabase-swift` indicato dalla documentazione Swift e dal repo GitHub ufficiale; pin risolto all'ultimo tag disponibile via SPM al momento dell'Execution (`2.46.0`).

#### Configurazione locale sicura

- File reale atteso: `iOSMerchandiseControl/SupabaseConfig.plist`
- File esempio tracciato: `iOSMerchandiseControl/SupabaseConfig.example.plist`
- Chiavi plist attese:
  - `SUPABASE_PROJECT_URL`
  - `SUPABASE_PUBLISHABLE_KEY`
- Procedura locale: copiare `SupabaseConfig.example.plist` in `SupabaseConfig.plist`, sostituire i placeholder con Project URL HTTPS e publishable/anon key pubblica client-side.
- `.gitignore` esclude `iOSMerchandiseControl/SupabaseConfig.plist`, `*.local.xcconfig`, `*.secrets.xcconfig`.
- Il loader non crasha se il plist reale manca: restituisce `configMissing`.
- Config invalida o placeholder: `invalidConfig`.
- Guardrail: rifiuto minimale di chiavi con indicatori `sb_secret_`, `service_role`, `secret_key`.
- Nessun logging di chiavi, JWT, header Authorization o segreti introdotto.

#### DTO e servizio readonly

- DTO aggiunti:
  - `RemoteInventoryProductRow`
  - `RemoteInventorySupplierRow`
  - `RemoteInventoryCategoryRow`
  - `RemoteInventoryProductPriceRow`
- DTO: `Codable`, `Sendable`, `CodingKeys` espliciti snake_case, nessun `@Model`, nessun `import SwiftData`.
- `inventory_product_prices.type` resta `String` (`PURCHASE` / `RETAIL`), senza conversione a `PriceType`.
- `effective_at` e `created_at` restano `String`, coerenti con schema auditato text.
- `deleted_at` incluso solo nei DTO catalogo (`suppliers`, `categories`, `products`), non nel DTO `RemoteInventoryProductPriceRow`.
- Servizio aggiunto come `actor SupabaseInventoryService`, non `@MainActor`, senza SwiftData / `ModelContext` / `modelContainer`.
- API esposte solo read-only:
  - `testConnection`
  - `fetchProducts`
  - `fetchSuppliers`
  - `fetchCategories`
  - `fetchProductPrices`
- Nessuna chiamata remota `.insert`, `.update`, `.upsert`, `.delete`, `.rpc`; nessuna API o funzione con nomi `save`, `sync`, `upsert`, `apply`, `merge`, `push`, `delete`, `mutate`.

#### Diagnostica UI minima

- `OptionsView` contiene una sezione diagnostica Supabase solo sotto `#if DEBUG`.
- UI coerente con `Form`, `Section`, `SectionHeader`, `Label`, `ProgressView`.
- Un solo bottone avvia `testConnection`.
- Esiti distinti:
  - config mancante
  - config invalida
  - rete/progetto non raggiungibile
  - RLS/auth (`permissionDeniedOrRLS`)
  - decoding error
  - schema drift
  - unknown
- Tutte le stringhe visibili aggiunte passano da `L("...")` e sono presenti in `it`, `en`, `es`, `zh-Hans`.

#### Esito build / diagnostica

- ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — build finale quiet: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → exit code `0`.
- ✅ ESEGUITO — warning scan su `/tmp/task034-build-final.log`: nessuna riga `warning:` trovata.
- ⚠️ NON ESEGUIBILE — catalog probe remoto reale: `iOSMerchandiseControl/SupabaseConfig.plist` reale non presente nel repo/workspace, quindi nessun Project URL/key reale disponibile. Blocco classificabile come `configMissing`; nessuna richiesta remota inviata, nessun codice HTTP/RLS reale disponibile. Il build product contiene solo `SupabaseConfig.example.plist`, non `SupabaseConfig.plist`.
- ⚠️ NON ESEGUIBILE — blocker RLS/auth reale: non raggiunto perché manca la configurazione reale. In base all'audit TASK-033 e alle migrazioni lette, un successivo probe con sola publishable/anon key può legittimamente fallire per RLS/auth e verrà classificato come `permissionDeniedOrRLS`.

#### Check eseguiti

- ✅ ESEGUITO — Build compila: PASS con comando `xcodebuild ... build`.
- ✅ ESEGUITO — Nessun warning nuovo verificabile: build quiet senza `warning:`.
- ✅ ESEGUITO — Modifiche coerenti con planning: scope limitato a Supabase foundation readonly + diagnostica DEBUG.
- ✅ ESEGUITO — DTO compilano e mappano lo schema auditato: PASS build; colonne confermate su migrazioni 013/016/019.
- ✅ ESEGUITO — `SupabaseInventoryService` non importa SwiftData: `rg "import SwiftData|ModelContext|modelContainer|context\\.insert|context\\.save" iOSMerchandiseControl/Supabase*.swift` senza match.
- ✅ ESEGUITO — Nessuna API write remota nei nuovi file Supabase: `rg "\\.insert\\(|\\.update\\(|\\.upsert\\(|\\.delete\\(|\\.rpc\\(|\\.auth\\b|func .*\\b(save|sync|upsert|apply|merge|push|delete|mutate)\\b" iOSMerchandiseControl/Supabase*.swift` senza match.
- ✅ ESEGUITO — Nessun segreto reale tracciato: nessun `SupabaseConfig.plist` reale trovato; example contiene solo placeholder.
- ✅ ESEGUITO — Config assente non crasha l'avvio: verifica statica/build; `SupabaseConfig.load()` è chiamato solo dal bottone diagnostico DEBUG, non da app startup.
- ✅ ESEGUITO — Nessuna modifica a `Models.swift`, `HistoryEntry.swift`, `InventorySyncService.swift`, `modelContainer`, schema SwiftData, import/export Excel o sync locale griglia → SwiftData.
- ✅ ESEGUITO — UI diagnostica non altera UX principale: sezione secondaria solo DEBUG in `OptionsView`.
- ✅ ESEGUITO — `git diff --check`: PASS.

#### Conferme esplicite

- **no push remoto**: confermato.
- **no sync automatico**: confermato.
- **no auth/login**: confermato.
- **no JWT manuale**: confermato.
- **no service_role**: confermato.
- **no scrittura SwiftData** da fetch remoto: confermato.
- **no modifica distruttiva ai modelli SwiftData / modelContainer**: confermato.
- **no dipendenze extra oltre Supabase Swift e transitive SPM risolte da Xcode**: confermato.

#### Rischi residui / follow-up candidate

- `SupabaseConfig.plist` reale non fornito: catalog probe live non eseguito. Prima della Review finale o in task successivo, fornire config locale non tracciata se si vuole evidenza runtime remota.
- RLS/auth live non verificato in ambiente hosted: lo schema auditato prevede `anon` senza grant e policy `authenticated` owner-scoped; eventuale errore RLS con sola chiave pubblica è atteso e non fallisce TASK-034.
- Possibile drift hosted vs migrazioni repo: gestito come `schemaDrift` / `decodingError` nel servizio diagnostico, ma non verificato live senza config reale.
- Follow-up candidate: task dedicato Auth/sessione Supabase iOS se serve superare RLS owner-scoped.
- Follow-up candidate: TASK-035 pull/dry-run senza scrittura locale.

### Handoff post-execution — verso Claude Review

- **Transizione richiesta**: `EXECUTION → REVIEW`.
- **Prossimo responsabile**: CLAUDE.
- **Stato task**: resta `ACTIVE`, non `DONE`.
- **Review richiesta su**:
  - correttezza integrazione SPM e target app;
  - separazione DTO/servizio da SwiftData;
  - classificazione errori e diagnostica DEBUG;
  - completezza localizzazioni;
  - accettabilità del blocker `configMissing` per catalog probe live in assenza di `SupabaseConfig.plist` reale.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review completata — 2026-05-04

- **Review status**: APPROVED
- **Esito**: TASK-034 coerente con TASK-033 e con il Planning. Perimetro rispettato: foundation Supabase iOS read-only, nessun sync automatico, nessun push, nessuna scrittura remota, nessuna scrittura SwiftData da fetch remoto, nessuna auth/login UI, nessun JWT manuale, nessun `service_role`, nessun multiutente.
- **File verificati**:
  - `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
  - `docs/SUPABASE/TASK-033-schema-audit.md`
  - `docs/MASTER-PLAN.md`
  - migrazioni Supabase catalogo/prezzi/tombstone `20260417120000_task013_inventory_catalog_rls.sql`, `20260417200000_task016_inventory_product_prices.sql`, `20260418200000_task019_inventory_catalog_tombstone.sql`
  - `iOSMerchandiseControl.xcodeproj/project.pbxproj`
  - `iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - `.gitignore`
  - `iOSMerchandiseControl/SupabaseConfig.swift`
  - `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
  - `iOSMerchandiseControl/SupabaseInventoryService.swift`
  - `iOSMerchandiseControl/SupabaseConfig.example.plist`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- **Micro-fix applicato in Review**: in `SupabaseInventoryService.swift` il dettaglio diagnostico sensibile redatto non produce più una stringa hardcoded in inglese visibile in UI; in caso di dettaglio potenzialmente sensibile viene omesso e resta il messaggio localizzato di base.
- **Dependency Supabase**: package `https://github.com/supabase/supabase-swift.git`, prodotto `Supabase`, versione risolta `2.46.0`; collegato al target app principale `iOSMerchandiseControl`, non al solo target test.
- **Config sicurezza**: `SupabaseConfig.example.plist` contiene solo placeholder; `SupabaseConfig.plist` reale non è presente e non è tracciato; `.gitignore` lo esclude insieme a xcconfig locali/segreti. Nessun segreto reale, nessun `Authorization`/`Bearer` hardcoded e nessun logging di chiavi/token rilevato. Le stringhe `service_role` / `sb_secret` / `secret_key` compaiono solo come guardrail di rifiuto in `SupabaseConfig.swift`.
- **DTO**: `RemoteInventoryProductRow`, `RemoteInventorySupplierRow`, `RemoteInventoryCategoryRow`, `RemoteInventoryProductPriceRow` sono `Codable`/`Sendable`, senza `@Model` e senza `import SwiftData`; `CodingKeys` snake_case espliciti; colonne allineate all'audit TASK-033 e alle migrazioni lette; `type` prezzi resta `String`; `effective_at` / `created_at` prezzi restano `String`; `deleted_at` solo sul catalogo.
- **Servizio readonly**: `SupabaseInventoryService` è `actor`, non `@MainActor`, senza SwiftData / `ModelContext` / `modelContainer`; espone solo `testConnection`, `fetchProducts`, `fetchSuppliers`, `fetchCategories`, `fetchProductPrices`; nessuna chiamata `insert` / `update` / `upsert` / `delete` / `rpc` / auth.
- **Diagnostica UI**: sezione Supabase solo sotto `#if DEBUG`, coerente con `OptionsView` esistente, un solo bottone diagnostico, loading state corretto, messaggi distinti per config, rete, RLS/auth, decoding, schema drift, unknown. Nessuna nuova schermata e nessun refactor UI ampio.
- **Localizzazioni**: chiavi diagnostiche presenti e validate in `it`, `en`, `es`, `zh-Hans`; nessuna stringa utente hardcoded residua nella diagnostica Supabase.
- **Non regressione SwiftData/app**: `Models.swift`, `HistoryEntry.swift`, `InventorySyncService.swift`, `modelContainer`, import/export Excel e sync locale griglia → SwiftData non sono stati modificati; nessuna persistenza locale dei dati remoti introdotta.
- **Check eseguiti**:
  - ✅ ESEGUITO — `git status --short`: solo file coerenti con TASK-034 Review/Execution.
  - ✅ ESEGUITO — `git diff --check`: PASS.
  - ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build`: **BUILD SUCCEEDED**.
  - ✅ ESEGUITO — `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build`: exit code `0`.
  - ✅ ESEGUITO — `rg "import SwiftData|ModelContext|modelContainer|context\\.insert|context\\.save" iOSMerchandiseControl/Supabase*.swift`: nessun match.
  - ✅ ESEGUITO — `rg "\\.insert\\(|\\.update\\(|\\.upsert\\(|\\.delete\\(|\\.rpc\\(|\\.auth\\b|func .*\\b(save|sync|upsert|apply|merge|push|delete|mutate)\\b" iOSMerchandiseControl/Supabase*.swift`: nessun match.
  - ✅ ESEGUITO — `rg "service_role|sb_secret|secret_key|Authorization|Bearer" ...`: solo match sui guardrail di rifiuto `service_role` / `sb_secret` / `secret_key`, nessun segreto o header/token hardcoded.
  - ✅ ESEGUITO — `git ls-files -- iOSMerchandiseControl/SupabaseConfig.plist`: nessun output; config reale non tracciata.
  - ✅ ESEGUITO — `find iOSMerchandiseControl -name 'SupabaseConfig.plist' -print`: nessun output; config reale assente dal workspace.
  - ✅ ESEGUITO — `plutil -lint` su `SupabaseConfig.example.plist` e localizzazioni `it/en/es/zh-Hans`: PASS.
- **Catalog probe remoto live**: ⚠️ NON ESEGUIBILE — manca `iOSMerchandiseControl/SupabaseConfig.plist` reale con URL/key. Il blocker documentato è `configMissing`; è accettabile per TASK-034 perché la foundation gestisce config assente senza crash e senza inizializzare automaticamente rete/client all'avvio.
- **Warning build**: il build non-quiet mostra il warning Xcode `Metadata extraction skipped. No AppIntents.framework dependency found.`; non è collegato ai file TASK-034 e la build quiet richiesta esce pulita con codice `0`.
- **Conclusione**: criteri di accettazione soddisfatti. TASK-034 sblocca TASK-035 come next candidate, senza attivarlo automaticamente.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non necessario: nessun passaggio a fase FIX. La Review ha applicato direttamente un micro-fix documentale/codice non bloccante e ha rieseguito i check.

---

## Chiusura

### Conferma utente
- [x] Utente ha confermato il completamento con override esplicito: se la Review passa, mettere TASK-034 in DONE e allineare l'andamento dei task.

### Follow-up candidate
- **TASK futuro (candidate, non progettato qui)**: **Auth / sessione Supabase** lato iOS, se serve ottenere JWT `authenticated` e superare **RLS owner-scoped** su `inventory_*` (blocker ammesso in TASK-034; implementazione e scoping in task dedicato).
- **TASK futuro (candidate, non progettato qui)**: **pull / sync / merge** controllato tra dati Supabase e **SwiftData** dopo la foundation readonly (fuori perimetro TASK-034; niente sync automatico né scrittura locale da remoto in questo task).

### Riepilogo finale
Foundation Supabase iOS read-only completata: dependency Supabase Swift, config locale sicura, DTO remoti, servizio readonly e diagnostica DEBUG localizzata. Nessun sync, push, auth/login, JWT manuale, `service_role`, scrittura remota o scrittura SwiftData da dati remoti introdotta.

### Data completamento
2026-05-04
