# TASK-038: Supabase Google Auth foundation iOS

## Informazioni generali
- **Task ID**: TASK-038
- **Titolo**: Supabase Google Auth foundation iOS
- **File task**: `docs/TASKS/TASK-038-supabase-google-auth-foundation-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Review / Codex — completed
- **Data creazione**: 2026-05-04
- **Ultimo aggiornamento**: 2026-05-05
- **Ultimo agente che ha operato**: Codex review/fix post-live TASK-038
- **Nota execution**: Execution avviata su override esplicito utente.

## Dipendenze
- **Dipende da**: TASK-034, TASK-035
- **Sblocca**: **TASK-039** — Supabase preview → apply locale controllato SwiftData (file task da creare al momento opportuno; dipende da sessione `authenticated` per RLS owner-scoped; deve gestire preview `partial` prima di apply)

## Scopo
Pianificare e, in una fase **EXECUTION** successiva (non autorizzata in questo turno), implementare una **foundation di login Google tramite Supabase Auth** su iOS, ottenendo una **sessione authenticated** riusabile dalle query PostgREST sulle tabelle `inventory_*` soggette a **RLS owner-scoped** (`auth.uid()` ↔ `owner_user_id`). **Dopo TASK-038**, il **preview cloud** e le letture catalogo nel perimetro devono essere **auth-gated**: **nessun fallback** a client anonimo né a fetch «senza sessione» come comportamento TASK-035 pre-login. TASK-038 include anche **diagnostica read-only post-login** (es. probe connessione/catalogo) sul **medesimo** client session-aware. TASK-038 è **solo auth/session/UI minima dev** — **nessun** sync dati, **nessun** apply SwiftData.

## Contesto
- **TASK-034** (DONE): client Supabase, `SupabaseConfig`, DTO readonly, `SupabaseInventoryService` read-only.
- **TASK-035** (DONE): preview pull dry-run Supabase → confronto SwiftData senza scrittura. **Nota evolution**: con TASK-038 **finalizzato**, il preview nel perimetro DEBUG diventa **auth-gated** (nessun fallback anon); il comportamento «solo publishable key senza sessione» non resta una strada supportata per il pull preview **dopo** questa slice.
- Le migrazioni e l’audit **TASK-033** confermano che `inventory_suppliers` / `inventory_categories` / `inventory_products` / `inventory_product_prices` espongono SELECT privilegiato al ruolo **`authenticated`** con policy **per proprietario** (`auth.uid() = owner_user_id`); `anon` è revocato sul catalogo — senza JWT di sessione le letture possono fallire o risultare vuote a seconda dell’ambiente (**permissionDeniedOrRLS** già tipizzato lato servizio inventory).
- Prima di un **apply locale** reale (TASK-039), serve una sessione utente valida allineata ai dati remoti (`owner_user_id`).

## Non incluso
- Nessun **apply** / merge / scrittura **SwiftData**
- Nessun **push** remoto (insert/update/upsert/delete/RPC mutanti)
- Nessun **sync automatico** o background sync
- Nessun ruolo **`service_role`** né chiavi segrete nel client
- Nessun **JWT manuale** hardcoded o incollato per aggirare RLS
- Nessuna **modifica schema** Supabase (DDL/policy) e nessuna migrazione SQL da questo task
- Nessuna modifica **distruttiva** ai modelli **SwiftData** esistenti
- Nessun login **email/password** salvo richiesta esplicita futura
- Nessuna gestione **multiutente avanzata** (switch account, team, inviti, ecc.)
- Nessun **Sign in with Apple** in questa slice — ma vedi § **Rischio App Store**
- Nessuna **nuova schermata** «Account» a tutto schermo: solo **`Section` dentro `OptionsView`** (Form/List), coerente con il pattern iOS esistente
- **Nessun SDK aggiuntivo** Google Sign-In / **Firebase** / auth Google nativo oltre a quanto richiesto da **`supabase-swift`** (SPM pinata) — salvo **blocker documentato** (issue/doc + decisione in review) che renda l’OAuth ufficiale Supabase impraticabile senza dipendenza extra
- **Nessuna execution** in questo turno: nessun file `.swift`, `Info.plist`, `project.pbxproj`, `Package.resolved` o configurazione Xcode modificata finché il planning non è approvato e l’utente non autorizza **EXECUTION**

## Stato attuale iOS (riassunto post-TASK-034/035)
- **`SupabaseConfig.swift`**: carica `SupabaseConfig.plist`, valida URL HTTPS + publishable key, `makeClient()` → `SupabaseClient` isolato (nessuna auth wiring).
- **`SupabaseInventoryService.swift`**: actor read-only; per ogni fetch costruisce **`let client = config.makeClient()`** — **debito architetturale**: in EXECUTION TASK-038 deve essere sostituito da **client session-aware iniettato** (§ **Decisione vincolante**).
- **`SupabasePullPreviewService.swift`**: usa `SupabaseInventoryService` per snapshot remoto + diff locale; **read-only**; oggi assume catena pre-auth (TASK-035). **Post TASK-038 EXECUTION**: preview **solo** con sessione valida — vedi § **Preview cloud auth-gated**.
- **`OptionsView.swift`**: sezione **DEBUG** per diagnostica connessione e **preview pull** (TASK-035); **nessuna** UI Account / login / stato sessione.
- **`iOSMerchandiseControlApp.swift`**: solo `WindowGroup` + `modelContainer`; **nessun** `onOpenURL` / `auth.handle(URL)` (o equivalente documentato in `supabase-swift`) / gestione callback OAuth.
- **`Localizable.strings`**: stringhe preview/diagnostica Supabase; **nessuna** stringa auth Google dedicata (da aggiungere in EXECUTION).
- **Gap**: mancano **`SupabaseClientProvider` (o equivalente) + DI**, **`SupabaseAuthService`** con OAuth/listener, **state machine** esposta allo UI, **`onOpenURL`**, e allineamento **Auth** ↔ **InventoryService/Preview** sul **medesimo** client session-aware.

## Riferimento Android (solo concettuale)
Nel repo Android (`MerchandiseControlSplitView`) esiste integrazione funzionale **Google + Supabase Auth**:
- **`SupabaseAuthManager.kt`**: possiede il `SupabaseClient` con modulo Auth, `StateFlow` per `AuthState`, restore sessione con timeout, `signInWithGoogle` via **Credential Manager** + **Google ID Token**, scambio con `client.auth.signInWith(IDToken) { provider = Google; idToken = … }`, sign-out, gestione cancellazione utente (`GetCredentialCancellationException`).
- **`MerchandiseControlApplication.kt`**: inietta `SupabaseAuthManager` e `BuildConfig.GOOGLE_WEB_CLIENT_ID`.
- **`OptionsScreen.kt` / `NavGraph.kt`**: UI «Accedi con Google».

Per **TASK-038 iOS** questo materiale serve solo come **proof** che account/sessione condivisa con Supabase è coerente col resto dell’ecosistema; **non** si copia Kotlin né il flusso **ID Token nativo** Android. Su iOS la slice pianificata usa **OAuth via Supabase Auth** (flusso browser / `ASWebAuthenticationSession` secondo documentazione `supabase-swift`), **senza Firebase Auth** separato.

## Riferimento Supabase (schema / RLS — TASK-033 e migrazioni locali)
Fonte: `docs/SUPABASE/TASK-033-schema-audit.md` e file sotto
`/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/` (es. `20260417120000_task013_inventory_catalog_rls.sql`, `20260417200000_task016_inventory_product_prices.sql`, ownership `20260417_task012_ownership_rls.sql`).

Confermato senza inventare colonne o tabelle:
- Tabelle catalogo/prezzi: **`owner_user_id`** con FK verso **`auth.users`**, policy **owner-scoped** con **`auth.uid() = owner_user_id`** per il ruolo **`authenticated`**; **`anon`** con **`REVOKE ALL`** sulle `inventory_*` pertinenti al catalogo (dettaglio grant/policy nel DDL delle migrazioni).
- **`sync_events`**: insert tramite RPC dedicata; out of scope per questa slice auth ma resta soggetta a sessione/authenticated dove previsto dall’audit.

Se dopo il login l’utente Google non coincide con il **`owner_user_id`** dei dati remoti caricati nel progetto Supabase, **RLS continuerà a negare** le righe: non è un bug iOS di per sé — va classificato come **`permissionDeniedOrRLS`** (o mapping dedicato) con messaggio distinto rispetto a sessione assente.

## Design iOS proposto (EXECUTION futura — elenco file)
| Elemento | Azione |
|----------|--------|
| **`iOSMerchandiseControl/SupabaseClientProvider.swift`** *(o equivalente)* | Nuovo **preferito**: incapsula **un solo** `SupabaseClient` session-aware per composition root; costruzione da `SupabaseConfig`; esposto via **dependency injection** (vedi § **Client condiviso**). Alternativa ammessa: stessa responsabilità **esplicita** dentro `SupabaseAuthService` se il file unico resta chiaro in review. |
| **`iOSMerchandiseControl/SupabaseAuthService.swift`** | Nuovo: OAuth Google (`signInWithOAuth` / sessione `ASWebAuthenticationSession` secondo doc pinata), **signOut**, sottoscrizione **listener** eventi auth; opera sul **client iniettato** dal provider — non `makeClient()` per richiesta sul servizio inventory. |
| **`iOSMerchandiseControl/SupabaseAuthViewModel.swift`** oppure **`AuthSessionStore.swift`** | Nuovo (scegliere un solo pattern in EXECUTION): `@MainActor` / `ObservableObject` — espone la **state machine** § **State machine** a SwiftUI; nessun `Bool` sparsi in `OptionsView`. |
| **`iOSMerchandiseControl/iOSMerchandiseControlApp.swift`** | Composition root: creare provider + servizi auth/inventory/preview con **iniezione**; **`onOpenURL`** → `supabase.auth.handle(url)` (o API ufficiale equivalente). |
| **`iOSMerchandiseControl/OptionsView.swift`** | Una **`Section`** nel `Form` esistente (nessuna nuova schermata): auth + preview **auth-gated** + **diagnostica read-only post-login** (probe solo con `signedIn`); vedi § **UX / UI**. |
| **`iOSMerchandiseControl/SupabaseInventoryService.swift`** | Refactor **vincolato**: **non** chiamare `config.makeClient()` per ogni fetch; usare il **`SupabaseClient`** (o provider) **iniettato** condiviso con auth. |
| **`iOSMerchandiseControl/SupabasePullPreviewService.swift`** | **Auth-gated**: avviare preview solo se state machine = `signedIn` (o sessione JWT presente sul client iniettato); se `signedOut` / `sessionMissing` → **nessun** fetch anonimo; messaggio UX + eventuale `sessionMissing`. Stesso client condiviso del login. |
| **`*/Localizable.strings`** | Chiavi per titoli, stati state-machine, errori auth (IT/EN/ES/ZH-Hans). |
| **`Info.plist` / URL Types** | Solo in EXECUTION: `CFBundleURLTypes` / URL scheme allineati a Supabase Redirect URLs (vedi § **Checklist esterna**). |

## Architettura richiesta (vincoli)

### Decisione vincolante — client Supabase condiviso e session-aware
- **`SupabaseInventoryService` non deve** continuare a creare un client separato **anonimo** con `SupabaseConfig.load()` + **`makeClient()`** a **ogni** operazione di rete.
- **Login Google** e **preview Supabase** devono utilizzare **lo stesso** `SupabaseClient` che mantiene la **sessione** dopo OAuth (JWT allegato dalle richieste successive).
- **Preferenza**: tipo **`SupabaseClientProvider`** (nome indicativo) che costruisce **una volta** il client da `SupabaseConfig` e lo condivide — **oppure** responsabilità **equivalente e ugualmente esplicita** concentrata in **`SupabaseAuthService`**, purché in review resti chiaro «chi possiede il client» e come inventory/preview lo ricevono.
- **Dependency injection** dal **composition root** (`iOSMerchandiseControlApp` o helper dedicato): iniettare il provider (o client) in **`SupabaseAuthService`**, **`SupabaseInventoryService`**, **`SupabasePullPreviewService`** / store UI. **Vietato** singleton globale **opaco** (es. accesso statico nascosto senza origine testabile e ciclo di vita documentato).
- Il pattern attuale TASK-034/035 (nuovo client per fetch) è **tecnicamente debito** e va **rimosso** in TASK-038 EXECUTION per le letture nel perimetro auth+inventory.

### Preview cloud auth-gated (obbligo post-TASK-038)
- **`SupabasePullPreviewService`** / pulsante preview in **DEBUG**: eseguibile **solo** quando l’utente è **`signedIn`** (sessione JWT sul client condiviso). Se **non autenticato**: **non** lanciare fetch catalogo; mostrare stato/CTA coerente (es. «Accedi…») o errore **`sessionMissing`** — **vietato** reintrodurre silenziosamente il percorso **anon** o un secondo client «solo per provare» senza sessione.
- **Obiettivo**: allineamento a RLS `authenticated` owner-scoped; nessuna ambiguità «preview funziona senza login» dopo questo task.
- **Regressione accettabile documentata**: oggi TASK-035 consente preview senza sessione (spesso `permissionDeniedOrRLS` o esito vuoto); dopo EXECUTION TASK-038 il comportamento atteso è **gate esplicito**, non fallback anon.

### Diagnostica post-login (read-only)
- Le azioni tipo **`testConnection`** / **catalog probe** (già presenti come pattern TASK-034) restano **sola lettura** e devono usare il **client autenticato** quando l’utente è `signedIn` — stesso `SupabaseClientProvider` del preview.
- Se `signedOut`: diagnosi **limitata** a messaggi di configurazione / invito al login — **niente** probe remoto che aggira sessione.

### SDK e dipendenze
- **Solo** flusso **Supabase OAuth ufficiale** tramite **`supabase-swift`** (versione **SPM pinata**). **Nessun** aggiunta di **Google Sign-In SDK** standalone, **Firebase Auth**, o simili — salvo **blocker** motivato (doc/issue/SDK), registrato in `Execution`/`Decisioni` e approvato in **REVIEW**.

### State machine auth (esplicita)
Esporre **un solo** modello di stato consumato da SwiftUI — **vietato** accumulare `Bool` / flag sparsi in `OptionsView` per derivare la UI.

Stati concettuali richiesti (nomi Swift finali = decisione EXECUTION):

| Stato | Descrizione |
|--------|-------------|
| `unconfigured` | Config plist assente o invalida → auth / sync cloud non utilizzabili |
| `signedOut` | Config valida, nessuna sessione utente |
| `signingIn` | OAuth avviato, in attesa di callback o completamento SDK |
| `signedIn` | Sessione attiva; email/user id disponibili secondo SDK (senza loggare token) |
| `signingOut` | Logout in corso |
| `failed` | Ultima transizione auth fallita; messaggio/codice localizzato per ripresentazione |

Transizioni ammesse e gestione race (es. tap multipli) da definire in EXECUTION; l’UI si limita a osservare questo stato + eventuali proprietà derivate (email, testo errore).

### Flusso OAuth iOS (rafforzato)
- **Solo** flusso **ufficiale Supabase Auth** per provider **Google** sulla versione **`supabase-swift` pinata** nel progetto.
- Usare **`signInWithOAuth`** con **`ASWebAuthenticationSession`** (o combinazione **documentata ufficialmente** per quella major/minor SPM), non un browser ad-hoc non raccomandato.
- **Callback**: `onOpenURL` → **`supabase.auth.handle(url)`** (o simbolo ufficiale equivalente se la API è stata rinominata nella pin).
- **Niente** estrazione manuale fragile di token da URL/fragment **salvo** assenza documentata nell’SDK e decisione motivata + review; preferire sempre il handler SDK.

### Listener eventi auth e ripristino sessione
Sottoscrivere gli eventi esposti da **`supabase-swift`** — in particolare il flusso documentato come **`authStateChanges`** (o nome equivalente nella pin) — per alimentare la state machine:
- **initial session** / caricamento sessione a cold start;
- **signed in**;
- **signed out**;
- **token refreshed** (se il SDK espone l’evento o equivalente `Session` aggiornato).

**Obiettivo**: sessione **ripristinabile dopo riavvio app** se il meccanismo di persistenza del SDK lo supporta (es. Keychain). Se la versione pinata non espone tutti i listener con granularità ideale, documentare nel task/handoff quali eventi sono effettivamente cablati.

### Persistenza, deep link, sicurezza log
- **Persistenza**: comportamento standard SDK (vedi doc pin); storage custom solo se obbligatorio e giustificato.
- **Deep link**: URL scheme / Redirect URL allineati a Supabase Dashboard — vedi § **Checklist esterna**.
- **Logging**: **nessun** access_token / refresh_token / JWT / query di redirect sensibile in `print` / OSLog / crash reports — vedi checklist.

### Errori localizzati e distinti (codice interno + stringa UI)
`configMissing`, `oauthCancelled`, `callbackFailed`, `sessionMissing`, `permissionDeniedOrRLS`, `unknown` — armonizzati con / estesi da `SupabaseInventoryServiceError` dove ha senso; in EXECUTION una sola tassonomia coerente per UI e diagnostica **safe**.

## UX / UI (`OptionsView` — nessuna nuova schermata)
- **Struttura**: una **`Section`** nel **`Form`** esistente, stile **List** iOS coerente con tema/lingua già in opzioni.
- **Visibilità**: contenuto auth / preview cloud solo in **`#if DEBUG`** (o equivalente); **Release** non deve mostrare UI dev se la protezione `#if DEBUG` è quella adottata — verificabile in CA.
- **Copy** header/footer: chiaro **«Accesso per sincronizzazione Supabase»**; **mai** «sync completata», «dati applicati», «merge eseguito».
- **Stato utente** tramite **`Label`** (o equivalente) con icona/systemImage appropriato:
  - non connesso (`signedOut` / `unconfigured` con messaggio distinto se serve);
  - accesso in corso (`signingIn` / `signingOut` con **ProgressView** inline);
  - connesso come **email** (se disponibile da `User` / JWT lato SDK);
  - errore (`failed` con messaggio localizzato, senza token).
- **Azioni** (nella Section DEBUG):
  - pulsante **primario**: **«Accedi con Google»** (disabilitato in `unconfigured` / durante `signingIn`);
  - **«Esci»**: stile **secondario** o **role `.destructive`** quando `signedIn`, disabilitato durante `signingOut`.
  - **Preview pull**: abilitato **solo** in `signedIn`; se `signedOut` → disabilitato o messaggio esplicito (nessun fetch anon).
  - **Diagnostica / test connessione** (read-only): **dopo login** (`signedIn`), stesso client della preview; se non connesso, solo messaggio config/login — **nessun** probe che simula anon.
- **DEBUG**: **`DisclosureGroup`** (o simile) per **userId** e indicazione **provider** (es. Google); **vietato** mostrare token o porzioni di URL con segreti.
- Nessun blocco della navigazione principale: flusso opzionale dalla tab Opzioni.

## Rischio App Store
Se l’app verrà distribuita su **App Store** e **Google** diventa il **login principale** o l’unico login social prominente, le linee guida Apple possono richiedere **Sign in with Apple** come alternativa equivalente (salvo eccezioni applicabili al caso specifico). Valutare un **task successivo** dedicato (Sign in with Apple + federazione Supabase o strategia multi-provider approvata legalmente/product) prima di un rilascio consumer che dipenda solo da Google.

## Criteri di accettazione (futuri — EXECUTION/REVIEW)
Contratto per la fase di implementazione; **non** verificabili in questo turno planning-only.
- [ ] Build **Debug** e **Release** verdi.
- [ ] **Release**: se l’UI auth/preview è protetta da **`#if DEBUG`**, nessun elemento dev-only visibile in Release; evidenza in review (screenshot o ispezione target).
- [ ] Con **config mancante** o invalida: **nessun crash**; stato `unconfigured` / `configMissing` / `invalidConfig` gestito.
- [ ] **Login Google** completo → **sessione Supabase** attiva sul **client condiviso** (stesso usato da inventory/preview); **nessun** token in log.
- [ ] **User id** dell’utente autenticato leggibile in UI (e/o **DisclosureGroup** DEBUG).
- [ ] **Logout** → sessione **eliminata** lato SDK/storage locale; UI torna a `signedOut`.
- [ ] **Preview cloud** (`SupabasePullPreviewService`): **solo** con utente **`signedIn`**; se non autenticato → **nessun** fetch catalogo; **nessun fallback anon** né secondo client «senza sessione» dopo TASK-038.
- [ ] **Diagnostica** read-only (test connessione / catalog probe): eseguita sul **client autenticato** quando `signedIn`; non sostituisce il login e non aggira RLS.
- [ ] **Dipendenze**: nessun SDK **Google Sign-In** / **Firebase** aggiunto oltre a **`supabase-swift`** pinata e transitivi — salvo **blocker** documentato e approvato in review.
- [ ] **RLS owner mismatch** (dati con `owner_user_id` ≠ utente corrente) → **`permissionDeniedOrRLS`** (o equivalente) **distinto** da **rete**, **config** e **`sessionMissing`** — documentato in handoff/review con esempio di messaggio safe.
- [ ] **OAuth cancellato** → `oauthCancelled` / ritorno a stato coerente senza crash.
- [ ] **Nessuna** scrittura **SwiftData** né **remota** (nessun apply, nessun push catalogo).
- [ ] **Nessun** `service_role`, **nessun** JWT hardcoded, **nessun** segreto in repository.
- [ ] **Stringhe** localizzate (IT/EN/ES/zh-Hans come dai `Localizable.strings` del target).
- [ ] **Nessuna** modifica distruttiva ai modelli **SwiftData**.
- [ ] **State machine** esposta come modello unico — **nessuna** logica auth basata su `Bool` sparsi in `OptionsView`.
- [ ] **Listener** **`authStateChanges`** (o API ufficiale equivalente nella pin) per initial session, signed in/out, token refresh se disponibile; sessione ripristinabile al relaunch se supportato.

## Checklist esterna obbligatoria (prima di validare EXECUTION)
Da spuntare in fase di test/smoke; non sostituisce i CA ma **blocca** un dichiarato «OAuth OK» se ignorate.

**Supabase Dashboard**
- [ ] Provider **Google** abilitato e credenziali OAuth coerenti con Google Cloud.
- [ ] **Redirect URLs** registrati (inclusi schema/i URL accettati dal client iOS e da `supabase.auth.handle`).
- [ ] **Site URL** coerente con il progetto (doc Supabase Auth).

**Google Cloud Console**
- [ ] **OAuth consent screen** configurato.
- [ ] Client (Web / iOS se richiesto) e ID applicativi allineati a quanto richiesto da Supabase + `supabase-swift`.

**iOS**
- [ ] **`CFBundleURLTypes`** / URL scheme registrati come da guida Supabase per la versione pinata; callback **testato** su device/simulator.
- [ ] **Nessun token** (access, refresh, JWT) in console log, crash log o UI.

## Matrice test minima (manuale / smoke — EXECUTION)
| # | Scenario | Esito atteso |
|---|----------|----------------|
| T-1 | Config mancante / plist assente | `unconfigured` o equivalente; nessun crash; nessun OAuth invocato senza config |
| T-2 | Provider Google non configurato lato Supabase/Google Cloud | Fallimento controllato; messaggio diagnostico **non** che espone segreti |
| T-3 | OAuth annullato dall’utente | `oauthCancelled` o `signedOut`; nessun hang |
| T-4 | Login completato | `signedIn`; sessione sul client condiviso; letture consentite se RLS consente |
| T-5 | Relaunch app (cold start) | Sessione ripristinata se supportata dal SDK; stato UI coerente |
| T-6 | Logout | `signedOut`; nessun JWT residuo utilizzabile per fetch |
| T-7 | Preview dopo login | `SupabasePullPreviewService` usa client autenticato — dati o errore RLS **distinto** |
| T-8 | RLS owner mismatch (dati di altro utente) | `permissionDeniedOrRLS` (o tipizzazione dedicata) ≠ network / config / sessionMissing |
| T-9 | Build **Release** | Compilazione verde; UI dev assente se protetta da DEBUG |
| T-10 | Preview / pull richiesto **senza** sessione (`signedOut`) | **Nessun** fetch anon; UI bloccata o errore `sessionMissing`; **zero** fallback silenzioso al client pre-TASK-038 |
| T-11 | Diagnostica read-only **dopo** login (probe connessione/catalogo) | Stesso client autenticato; solo SELECT/read-only; esito coerente con RLS |
| T-12 | Grafo dipendenze SPM | **Nessun** pacchetto Google Sign-In/Firebase Auth aggiunto salvo **blocker** documentato + decisione review |

## Rischi
| Rischio | Nota |
|---------|------|
| **Redirect URL errato** | OAuth completa ma sessione non si stabilisce; richiede allineamento Dashboard ↔ `Info.plist` ↔ codice callback. |
| **URL scheme non configurato** | iOS non riceve il redirect; `callbackFailed`. |
| **Provider Google non abilitato** in Supabase / client OAuth Google | Fallimento a runtime; documentare messaggio `unknown` vs diagnostico leggibile. |
| **Mismatch `owner_user_id`** dati remoti vs account Google | RLS restituisce vuoto o errore — distinto e documentato (`permissionDeniedOrRLS`). |
| **App Store** | Sign in with Apple se Google è login primario — vedi § sopra. |
| **Persistenza sessione** | Sessione persa al riavvio se storage SDK mal configurato o refresh non gestito — verificare doc versione SPM in EXECUTION. |
| **DI incompleta / provider duplicato** | Due istanze `SupabaseClient` → login su una e fetch sull’altra; mitigazione: **un** provider iniettato dal composition root; review verifica wiring. |
| **Dipendenze extra non richieste** | Aggiunta SDK Google/Firebase per «semplificare» OAuth → scope creep; solo **blocker** documentato può giustificarla. |
| **Fallback anon per preview** | Tentativo di mantenere fetch senza login → viola auth-gated; **vietato** dopo TASK-038. |

## Check finali del planning (questo turno)
- [x] **TASK-038** resta **ACTIVE** / **PLANNING** — **nessuna EXECUTION** autorizzata.
- [x] Nessun codice **Swift** modificato.
- [x] Nessun **`Info.plist`**, **`project.pbxproj`**, **`Package.resolved`**, né configurazione Xcode modificata.
- [x] Solo aggiornamento **`docs/TASKS/TASK-038-supabase-google-auth-foundation-ios.md`** e, se necessario, **`docs/MASTER-PLAN.md`** per tracking coerente.
- [x] **Planning finalizzato** accettato: preview **auth-gated** (no fallback anon), diagnostica **post-login** read-only, divieto SDK Google/Firebase extra salvo blocker, `authStateChanges`, matrice **T-1…T-12**, **TASK-039** candidato invariato.
- [x] **MASTER-PLAN** coerente: un solo task attivo (**TASK-038**).
- [x] **TASK-034** e **TASK-035** restano **DONE**.
- [x] **TASK-039** indicato come prossimo candidate: **Supabase preview → apply locale controllato SwiftData**.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|----------------------|-------------|-------|
| D-1 | iOS: OAuth Supabase (`signInWithOAuth` / `ASWebAuthenticationSession` o equivalente ufficiale) per Google | Copia 1:1 Credential Manager + `IDToken` Android | Pattern iOS + doc `supabase-swift` pinata | attiva |
| D-2 | Auth foundation prima di TASK-039 apply | Apply senza sessione | RLS owner-scoped richiede JWT authenticated | attiva |
| D-3 | **Obbligo** `SupabaseClient` **unico** session-aware condiviso tra auth, inventory, preview | `makeClient()` per ogni fetch in `SupabaseInventoryService` | Login e letture devono condividere JWT/sessione | attiva |
| D-4 | **`SupabaseClientProvider`** (o equivalente **esplicito** in `SupabaseAuthService`) + **dependency injection** dal `App` | Singleton globale **opaco** senza composition root | Testabilità, ciclo di vita chiaro, no client duplicati | attiva |
| D-5 | **State machine** auth centralizzata (`unconfigured` … `failed`) | Booleani sparsi in `OptionsView` | UX coerente, meno race/truth duplicati | attiva |
| D-6 | **Preview cloud auth-gated**; **nessun fallback anon** dopo TASK-038 | Mantenere fetch senza login «per comodità» | Allineamento RLS `authenticated`; un solo modello mentale | attiva |
| D-7 | **Diagnostica read-only post-login** sul client condiviso | Probe anon paralleli | Coerenza sessione e sicurezza | attiva |
| D-8 | **Nessun SDK Google/Firebase extra** salvo **blocker** documentato + review | Dipendenze redundant | Perimetro minimo; OAuth via Supabase ufficiale | attiva |

---

## Planning (Claude / Planner) ← sezione planning operativa

### Obiettivo
Fornire una base **auth/session** iOS sicura e localizzata che sblocchi operazioni **read/write** future sul cloud solo **dopo** verifica RLS e product decisions — senza introdurre sync o apply nel perimetro TASK-038.

### Analisi
Il progetto ha già rete read-only verso `inventory_*` ma il client non gestisce sessione e **ricrea** `SupabaseClient` per richiesta. L’architettura Supabase lato server presuppone `authenticated` per il catalogo. Il gap principale è **un client session-aware condiviso (DI)** + **lifecycle OAuth ufficiale** + **state machine** + **listener** + **hook URL** + **Section OptionsView** senza nuova schermata.

### Approccio proposto
1. Introdurre **`SupabaseClientProvider`** (o equivalente) + **injection** da `iOSMerchandiseControlApp` a `SupabaseAuthService`, `SupabaseInventoryService`, `SupabasePullPreviewService`.
2. Implementare **`SupabaseAuthService`** con OAuth Google via **`signInWithOAuth`** / **`ASWebAuthenticationSession`** (o equivalente **ufficiale** pinata), **signOut**, **`onOpenURL` → `handle(url)`**; sottoscrivere **`authStateChanges`** (o equivalente): initial session, signed in/out, token refresh se esiste.
3. Implementare **store/VM** che espone solo la **state machine** § documentata — `OptionsView` **non** deriva stato da booleani locali.
4. **Gate** preview e **diagnostica remota** su `signedIn`; rimuovere qualsiasi percorso **anon** implicito dopo TASK-038.
5. Aggiungere **`onOpenURL`** nell’`App`; aggiornare **`OptionsView`** **Section** (Label, ProgressView, pulsanti, DisclosureGroup DEBUG).
6. Verificare **SPM**: nessun Google Sign-In/Firebase Auth aggiunto salvo blocker documentato.
7. Completare **checklist esterna** + **matrice T-1…T-12** in review; evidenze build Debug/Release; nessuna scrittura SwiftData/remota.

### File coinvolti (EXECUTION futura)
Elenco in § **Design iOS proposto**; possibili touch aggiuntivi solo se emergono vincoli Xcode (capability Associated Domains, ecc.) — documentare in Execution.

### Rischi
Vedi tabella § **Rischi**; nessuna mitigazione codice in questo turno.

### Handoff post-planning
- **Stato / fase**: **ACTIVE / PLANNING** — **nessun passaggio a EXECUTION** senza **override esplicito** dell’utente.
- **Prossima fase** (dopo approvazione): **EXECUTION**.
- **Prossimo agente**: **CODEX** / Cursor executor.
- **Azione consigliata**: seguire § **Checklist esterna**; implementare provider+DI, `authStateChanges`, gate preview/diagnostica, OAuth ufficiale + `handle(url)`; evidenze **T-1…T-12** + build Release; **nessun** SDK Google/Firebase extra salvo blocker file task + review.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Avvio Execution — 2026-05-05

- Execution avviata su override esplicito utente.
- Task attivo verificato nel MASTER-PLAN: `TASK-038`, file task coerente con il filesystem.
- Fase aggiornata a `EXECUTION`; responsabile attuale `Cursor/Codex executor`.
- Fonti obbligatorie lette prima delle modifiche: MASTER-PLAN, TASK-038, TASK-034, TASK-035, audit schema TASK-033, file Supabase/Options/App/localizzazioni, `Package.resolved` e impostazioni progetto rilevanti.
- Obiettivo compreso: foundation iOS Google OAuth tramite Supabase Auth con client session-aware condiviso via DI; preview e diagnostica DEBUG auth-gated; nessun fallback anon; nessun apply SwiftData; nessuna scrittura remota.
- Piano minimo prima del codice: introdurre provider client condiviso; creare auth service e store state-machine; iniettare provider/service/store dal composition root; aggiornare `OptionsView` con Section DEBUG auth e gate preview/diagnostica; aggiornare localizzazioni; verificare build/check e compilare handoff.

### Completamento Execution — 2026-05-05

#### File modificati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-038-supabase-google-auth-foundation-ios.md`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Info.plist`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

#### Decisioni implementative effettive
- Introdotto `SupabaseClientProvider`, costruito una sola volta da `SupabaseConfig` nel composition root e iniettato in auth, inventory e preview. Nessun singleton globale opaco.
- Rimosso il pattern `config.makeClient()` per fetch: `SupabaseConfig` non espone piu' `makeClient()` e `SupabaseInventoryService` usa il provider condiviso.
- Implementato `SupabaseAuthService` con API ufficiali `supabase-swift` pinata `2.46.0`: `signInWithOAuth(provider: .google, redirectTo:)`, `ASWebAuthenticationSession` configurata dal SDK, `signOut`, `auth.handle(url)`, listener `authStateChanges` per initial session, signed in, signed out e token refreshed.
- Implementato `SupabaseAuthViewModel` come state machine unica: `unconfigured`, `signedOut`, `signingIn`, `signedIn`, `signingOut`, `failed`. Tap multipli disabilitati durante transizioni.
- Aggiornato `iOSMerchandiseControlApp` come composition root: provider, auth service, inventory service e preview service condividono lo stesso client; `onOpenURL` inoltra la callback OAuth allo store auth.
- Aggiornato `OptionsView` con Section DEBUG/dev-only per "Accesso per sincronizzazione Supabase", stato auth, `ProgressView`, login/logout, diagnostica e preview auth-gated, `DisclosureGroup` DEBUG con userId/provider/email. Nessun token in UI.
- Preview e diagnostica ora richiedono stato `signedIn` lato UI e sessione presente lato service; se manca sessione restituiscono `sessionMissing` senza fetch anon.
- `permissionDeniedOrRLS` resta distinto da rete/config/sessione nelle stringhe safe UI.
- Aggiunto URL scheme iOS `com.niwcyber.iosmerchandisecontrol` con redirect da registrare in Supabase Dashboard: `com.niwcyber.iosmerchandisecontrol://login-callback`.
- Aggiunte localizzazioni IT/EN/ES/ZH-Hans. Nessuna stringa utente auth aggiunta hardcoded in SwiftUI.
- Nessuna nuova dipendenza, nessun SDK Google Sign-In/Firebase, nessuna modifica a `Package.resolved`, nessuna modifica finale a `project.pbxproj`.

#### Check build/test
| Check | Stato | Evidenza |
|---|---|---|
| Build Debug compila | ✅ ESEGUITO | `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` PASS |
| Build Release compila | ✅ ESEGUITO | `xcodebuild -quiet -configuration Release -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` PASS |
| XCTest esistenti | ✅ ESEGUITO | `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1'` PASS, 18 test passati |
| Localizzazioni / plist validi | ✅ ESEGUITO | `plutil -lint iOSMerchandiseControl/Info.plist iOSMerchandiseControl/*.lproj/Localizable.strings` PASS |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Build Debug/Release PASS; unico warning osservato durante test: `Metadata extraction skipped. No AppIntents.framework dependency found`, gia' legato al target senza AppIntents e non introdotto dal codice TASK-038 |
| Modifiche coerenti con planning | ✅ ESEGUITO | Provider condiviso, OAuth Supabase ufficiale, state machine, DEBUG Section, auth-gate preview/diagnostica implementati |
| Criteri di accettazione verificati | ✅ ESEGUITO / ⚠️ PARZIALE LIVE | Verificati static/build/test/localizzazioni/anti-scrittura; OAuth reale e RLS live non eseguibili senza dashboard/config credenziali reali |

#### Matrice T-1...T-12
| Test | Tipo verifica | Esito / evidenza |
|---|---|---|
| T-1 Config mancante / plist assente | STATIC + BUILD | ✅ ESEGUITO: composition root cattura `configMissing`/`invalidConfig`, auth VM parte `unconfigured`, servizi Supabase nil, nessun OAuth/fetch remoto avviato senza config. Build PASS. |
| T-2 Provider Google non configurato | MANUAL/LIVE | ⚠️ NON ESEGUIBILE: richiede Supabase Dashboard/Google Cloud reali. Implementazione mantiene errore safe `unknown`/`callbackFailed` senza segreti. |
| T-3 OAuth annullato | STATIC | ✅ ESEGUITO: `ASWebAuthenticationSessionError.canceledLogin` mappato a `oauthCancelled`; stato torna coerente senza token/log. Live non eseguito per mancanza dashboard/config. |
| T-4 Login completato | MANUAL/LIVE | ⚠️ NON ESEGUIBILE: richiede provider Google abilitato e redirect registrato. Codice usa `signInWithOAuth(.google)` e stesso client condiviso per sessione/fetch. |
| T-5 Relaunch app | STATIC | ✅ ESEGUITO: listener `authStateChanges` gestisce `initialSession`; persistenza demandata allo storage standard SDK. Smoke reale non eseguito senza sessione live. |
| T-6 Logout | STATIC | ✅ ESEGUITO: `signOut()` cablato, stato `signingOut` -> `signedOut`, session info azzerata. Live non eseguito senza sessione reale. |
| T-7 Preview dopo login | STATIC + BUILD | ✅ ESEGUITO: pulsante preview abilitato solo `signedIn`; `SupabasePullPreviewService` usa `SupabaseInventoryService` iniettato; inventory richiede sessione. Live dati/RLS non eseguito. |
| T-8 RLS owner mismatch | STATIC | ✅ ESEGUITO: mapping `permissionDeniedOrRLS` mantenuto distinto da rete/config/sessionMissing e localizzato. Live mismatch non eseguito senza dataset/account dashboard. |
| T-9 Build Release | BUILD + STATIC | ✅ ESEGUITO: Release build PASS; UI auth/preview/diagnostica resta sotto `#if DEBUG` in `OptionsView`. |
| T-10 Preview senza sessione | STATIC + BUILD | ✅ ESEGUITO: UI disabilita preview se non `signedIn`; guardia service `requireAuthenticatedSession()` restituisce `sessionMissing`; nessun fallback anon e nessun secondo client. |
| T-11 Diagnostica post-login | STATIC + BUILD | ✅ ESEGUITO: diagnostica remota abilitata solo `signedIn` e usa `SupabaseInventoryService` condiviso/session-aware. Live probe non eseguito. |
| T-12 Grafo SPM senza Google/Firebase extra | STATIC | ✅ ESEGUITO: ricerca in `Package.resolved`, `project.pbxproj` e sorgenti: nessun `GoogleSignIn`/Firebase; dipendenze non aggiornate. |

#### Conferme anti-segreti / anti-scrittura
- ✅ ESEGUITO: nessun `service_role` configurato/hardcoded, JWT hardcoded, access token o refresh token introdotto; l'unica occorrenza testuale `service_role` nei sorgenti e' la guardia esistente di `SupabaseConfig` che rifiuta chiavi server-only.
- ✅ ESEGUITO: nessun token in UI, errori, diagnostica o log.
- ✅ ESEGUITO: `SupabaseConfig.plist` reale resta fuori git e non e' stato creato.
- ✅ ESEGUITO: nessuna modifica schema Supabase.
- ✅ ESEGUITO: nessuna scrittura remota (`insert/update/upsert/delete/rpc`) nel perimetro modificato.
- ✅ ESEGUITO: nessun apply SwiftData, nessun `context.save`, nessun `context.insert/delete` introdotto.

#### Rischi residui / blocker
- OAuth reale non validabile in questo ambiente senza configurazione Dashboard Supabase + Google Cloud + redirect registrato. Redirect URL da configurare: `com.niwcyber.iosmerchandisecontrol://login-callback`.
- RLS owner mismatch non validato live senza dataset Supabase con `owner_user_id` diverso dall'utente Google di test; la tipizzazione lato codice e UI e' predisposta.
- Persistenza sessione dopo relaunch dipende dal comportamento standard di `supabase-swift`/Keychain; listener initial session cablato, smoke live rimane da eseguire quando disponibile un account test.

### Handoff post-execution
- **Transizione**: `EXECUTION` -> `REVIEW`.
- **Prossimo agente**: Claude / Review.
- **Stato task**: `ACTIVE`, **non** `DONE`.
- **Perimetro consegnato**: foundation Google OAuth Supabase iOS, client condiviso session-aware, state machine auth, `OptionsView` DEBUG auth-gated, diagnostica/preview su client autenticato condiviso, localizzazioni, URL scheme.
- **Da verificare in review**: coerenza DI provider unico, assenza fallback anon, correttezza API `supabase-swift` pinata, protezione `#if DEBUG`, copy localizzato, mapping `sessionMissing`/`permissionDeniedOrRLS`, anti-segreti/anti-scrittura.
- **Blocker live dichiarati**: OAuth/RLS smoke reali T-2/T-4/T-5/T-7/T-8/T-11 richiedono configurazione esterna non presente in repo.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

Non avviato come fase separata: la review ha applicato direttamente fix piccoli e recuperabili, senza passaggio formale a `FIX`.

### Handoff post-fix
Non applicabile.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Review tecnica completata — 2026-05-05

- **Review status**: **APPROVED_FIXED_DIRECTLY**
- **User override**: l'utente ha autorizzato esplicitamente la review tecnica da Codex e la chiusura diretta in `DONE` se i criteri risultavano soddisfatti dopo eventuali fix piccoli.
- **Perimetro verificato**: foundation Google OAuth Supabase iOS; client Supabase condiviso session-aware; state machine auth; `OptionsView` DEBUG auth-gated; preview/diagnostica senza fallback anon; nessun apply SwiftData; nessun push remoto; nessun SDK Google/Firebase extra.

#### File letti / controllati in review

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-038-supabase-google-auth-foundation-ios.md`
- `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
- `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md`
- `docs/SUPABASE/TASK-033-schema-audit.md`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Info.plist`
- `iOSMerchandiseControl/*.lproj/Localizable.strings`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
- `iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- test XCTest Supabase/preview esistenti.

#### Architettura / DI

- ✅ **APPROVED**: `SupabaseClientProvider` costruisce un solo `SupabaseClient` da `SupabaseConfig` e lo espone a `SupabaseAuthService`, `SupabaseInventoryService` e `SupabasePullPreviewService` dal composition root `iOSMerchandiseControlApp`.
- ✅ **APPROVED**: `SupabaseInventoryService` non crea piu' client anonimi per fetch; `SupabaseConfig.makeClient()` e' rimosso.
- ✅ **APPROVED**: Auth, inventory, diagnostica e preview usano lo stesso provider/client session-aware. Nessun singleton globale opaco.
- ✅ **APPROVED**: `iOSMerchandiseControlApp` resta composition root leggibile; l'unico wiring aggiunto e' quello Supabase, senza refactor estranei al task.

#### Auth OAuth Google

- ✅ **APPROVED**: API `supabase-swift` pinata `2.46.0` verificate anche sul sorgente locale SPM: `signInWithOAuth(provider:redirectTo:)` usa `ASWebAuthenticationSession`, supporta PKCE e restituisce `Session`.
- ✅ **APPROVED**: `SupabaseAuthService.signInWithGoogle()` usa `signInWithOAuth(provider: .google, redirectTo: provider.redirectURL)`.
- ✅ **APPROVED**: `onOpenURL` inoltra a `auth.handle(url)`; callback e sessione OAuth sono gestite dall'SDK, senza parsing manuale di token.
- ✅ **APPROVED**: listener `authStateChanges` cablato per `initialSession`, `signedIn`, `signedOut`/`userDeleted`, `tokenRefreshed`; `SupabaseAuthViewModel` espone una state machine unica.
- ✅ **APPROVED**: logout chiama `signOut()`, azzera `sessionInfo` e torna a `signedOut`; cancellazione OAuth (`ASWebAuthenticationSessionError.canceledLogin`) e' mappata a `oauthCancelled` senza lasciare transizioni bloccate.

#### Auth-gate preview / diagnostica

- ✅ **APPROVED**: `OptionsView` abilita preview e diagnostica solo quando `supabaseAuthViewModel.isSignedIn` e i servizi sono disponibili.
- ✅ **APPROVED**: esiste guardia service-level in `SupabaseInventoryService.requireAuthenticatedSession()`; se manca la sessione viene restituito `sessionMissing` prima di qualunque fetch.
- ✅ **APPROVED**: `SupabasePullPreviewService` usa `SupabaseInventoryService` iniettato, quindi eredita il client autenticato e la guardia `sessionMissing`.
- ✅ **APPROVED**: `permissionDeniedOrRLS` resta distinto da `networkError`, config invalida/mancante e `sessionMissing`.

#### Sicurezza / dipendenze

- ✅ **APPROVED_FIXED_DIRECTLY**: nessun segreto reale, `service_role`, access token, refresh token o JWT hardcoded introdotto. Le uniche occorrenze testuali sono guardrail di rifiuto/sanitizzazione e il test sintetico.
- ✅ **APPROVED_FIXED_DIRECTLY**: `SupabaseConfig.swift` ora rifiuta anche chiavi legacy `service_role` in formato JWT decodificando il payload `role`, senza respingere un JWT con ruolo `anon`.
- ✅ **APPROVED**: `SupabaseConfig.plist` reale non e' tracciato; nella review finale post-test live e' presente solo localmente e risulta ignorato da git (`!!`), con `.gitignore` dedicato.
- ✅ **APPROVED**: nessuna scrittura remota (`insert/update/upsert/delete/rpc`), nessuna modifica schema Supabase, nessun apply SwiftData o `context.save/insert/delete` introdotto.
- ✅ **APPROVED**: `Package.resolved` contiene `supabase-swift` e transitivi legittimi; nessun Google Sign-In SDK, Firebase Auth o dipendenza extra non autorizzata.
- ✅ **APPROVED**: `project.pbxproj` collega solo il prodotto `Supabase` al target app; nessun refactor Xcode non necessario rilevato.

#### UI/UX / localizzazioni / Info.plist

- ✅ **APPROVED_FIXED_DIRECTLY**: header Section auth localizzato allineato al copy richiesto: "Accesso per sincronizzazione Supabase" / equivalenti EN/ES/ZH-Hans.
- ✅ **APPROVED**: `OptionsView` usa una sola `Section` DEBUG nel `Form`; nessuna schermata Account separata.
- ✅ **APPROVED**: stato con `Label`, `ProgressView` durante login/logout/diagnostica, login/logout disabilitati durante transizioni, preview/diagnostica disabilitate senza sessione, `DisclosureGroup` DEBUG senza token.
- ✅ **APPROVED**: nessuna stringa utente auth hardcoded in SwiftUI; chiavi IT/EN/ES/ZH-Hans complete e allineate.
- ✅ **APPROVED**: `Info.plist` contiene `CFBundleURLTypes` con scheme `com.niwcyber.iosmerchandisecontrol`, coerente con redirect `com.niwcyber.iosmerchandisecontrol://login-callback`; nessun segreto nel plist.
- ✅ **APPROVED**: UI auth/preview/diagnostica e sheet preview restano sotto `#if DEBUG`; Release build verde e ispezione statica confermano assenza di entry point dev in Release.

#### Fix diretti applicati in Review

- `iOSMerchandiseControl/SupabaseConfig.swift`: aggiunto controllo del payload JWT legacy per rifiutare ruolo `service_role` anche quando non compare in chiaro nella stringa della chiave.
- `iOSMerchandiseControlTests/SupabaseConfigSecurityTests.swift`: aggiunto test per chiave legacy JWT `service_role` rifiutata e JWT ruolo `anon` non respinto per falso positivo.
- `iOSMerchandiseControl/*/Localizable.strings`: header della Section auth rifinito per aderire al copy di planning.

#### Check eseguiti

| Check | Stato | Evidenza |
|---|---|---|
| Build Debug compila | ✅ ESEGUITO | `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → PASS |
| Build Release compila | ✅ ESEGUITO | `xcodebuild -quiet -configuration Release -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → PASS |
| XCTest | ✅ ESEGUITO | `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1'` → **TEST SUCCEEDED**, 19 test PASS |
| Nessun warning nuovo | ✅ ESEGUITO | Build Debug/Release quiet senza output; durante XCTest resta solo warning Xcode preesistente `Metadata extraction skipped. No AppIntents.framework dependency found.` |
| `plutil -lint` | ✅ ESEGUITO | `Info.plist` + `en/es/it/zh-Hans Localizable.strings` OK |
| Localizzazioni complete | ✅ ESEGUITO | 580 chiavi per ciascun `Localizable.strings`; nessuna chiave mancante/extra vs EN |
| `git diff --check` | ✅ ESEGUITO | PASS |
| `makeClient` residuo nel codice | ✅ ESEGUITO | Nessun match in sorgenti/progetto/SPM resolved; solo riferimenti storici nei markdown di planning |
| Segreti/token | ✅ ESEGUITO | Match solo su guardrail/sanitizzazione e test sintetico; nessun token, header Authorization, Bearer, access/refresh token o segreto reale |
| Scritture remote/locali | ✅ ESEGUITO | Nessun `.insert/.update/.upsert/.delete/.rpc` nei file Supabase/Options; nessun `context.insert/delete/save` nel perimetro TASK-038 |
| Google/Firebase extra | ✅ ESEGUITO | Nessun match `GoogleSignIn`/`Firebase` in sorgenti, progetto o `Package.resolved` |
| Release dev-only | ✅ ESEGUITO | Ispezione statica: Section auth/preview/diagnostica e sheet sotto `#if DEBUG`; Build Release PASS |
| Criteri di accettazione | ✅ ESEGUITO | Criteri static/build/test soddisfatti; review finale post-test live registra OAuth Google, redirect app e dry-run auth-gated PASS su Simulator |

#### Configurazione esterna richiesta

- **Supabase Dashboard**: abilitare provider Google, registrare Redirect URL `com.niwcyber.iosmerchandisecontrol://login-callback`, verificare Site URL/redirect consentiti.
- **Google Cloud Console**: configurare OAuth consent screen e client OAuth coerenti con Supabase Auth.
- **Live blocker residuo**: smoke OAuth/RLS owner-scoped eseguito dall'utente con config reale locale e account Google; eventuali mismatch futuri `owner_user_id` devono restare `permissionDeniedOrRLS`, non bug iOS.

#### Rischi residui / follow-up candidate

- Smoke reale login + redirect + preview/RLS dry-run eseguito dall'utente; rilancio app/logout restano smoke manuali utili ma non bloccanti per TASK-038.
- **TASK-039** resta candidate, non attivo: Supabase preview → apply locale controllato SwiftData. Deve bloccare apply quando la preview e' `partial` oppure implementare fetch completo/paginazione controllata per apply.
- Bridge `remoteId` / refs SwiftData, push manuale tombstone-compliant, Sign in with Apple e sync avanzata restano fuori scope.

---

### Review finale post-test live — 2026-05-05

#### Esito

**APPROVED_FIXED_DIRECTLY**. TASK-038 resta **DONE / Chiusura**: l'evidenza live fornita dall'utente conferma che Google OAuth iOS funziona end-to-end, il redirect `com.niwcyber.iosmerchandisecontrol://login-callback` rientra nell'app, la UI localizzata ZH-Hans mostra l'account connesso e il dry-run Supabase parte solo dopo login usando il client condiviso autenticato.

#### Evidenza live registrata

- Login Google iOS PASS: apertura `accounts.google.com`, redirect all'app PASS.
- Stato UI PASS: `OptionsView` mostra "已连接为 xniw97@gmail.com".
- Preview Supabase dopo login PASS: `远程商品: 10000`, `本地商品: 16789`, `新增: 1455`, `更新候选: 4575`, `冲突: 0`, `远程墓碑: 0`, `警告: 1000`, `未变化: 3970`.
- Preview parziale coerente con cap corrente: marcata "部分预览" e "价格历史未完全验证"; non corretta in TASK-038 perche' fuori scope apply.

#### Problemi / rumori valutati

- Supabase Swift 2.46.0 warning `Initial session emitted after attempting to refresh the local stored session...`: problema piccolo recuperabile. La sorgente SDK locale conferma che l'opt-in consigliato e' `emitLocalSessionAsInitialSession: true`, a patto di controllare `session.isExpired`.
- CoreData/SwiftData Simulator warning `Persistence-1526` vs `Persistence-1522`: classificato come store locale del Simulator da cancellare, non regressione TASK-038; nessuna migration SwiftData introdotta.
- Preview `partial` con remote products = `10000`: coerente col cap preview. TASK-039 dovra' bloccare apply quando preview e' `partial` oppure implementare fetch completo/paginazione controllata prima di qualunque apply.
- `project.pbxproj`: rilevato solo rumore Xcode di riordinamento del file reference del target test; rimosso dal diff. Nessun riferimento a `SupabaseConfig.plist` reale nel progetto.

#### Fix diretti aggiuntivi post-live

- `iOSMerchandiseControl/SupabaseClientProvider.swift`: impostato `emitLocalSessionAsInitialSession: true` nelle opzioni auth Supabase.
- `iOSMerchandiseControl/SupabaseAuthService.swift`: `SupabaseAuthSessionInfo` ora trasporta `isExpired` derivato da `Session.isExpired`, senza esporre token.
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`: inizializzazione, `isSignedIn`, `signIn` e listener eventi non marcano piu' `signedIn` se la sessione locale e' scaduta; il successivo refresh SDK puo' riaprire lo stato con `tokenRefreshed`.
- `iOSMerchandiseControl/OptionsView.swift`: `DisclosureGroup` debug sessione visibile solo con sessione effettivamente `signedIn`, sempre senza token.

#### Check finale post-live

| Check | Stato | Evidenza |
|---|---|---|
| Build Debug compila | ✅ ESEGUITO | `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → PASS |
| Build Release compila | ✅ ESEGUITO | `xcodebuild -quiet -configuration Release -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → PASS |
| XCTest | ✅ ESEGUITO | `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1'` → **TEST SUCCEEDED**, 19 test PASS |
| `plutil -lint` | ✅ ESEGUITO | `Info.plist` + `en/es/it/zh-Hans Localizable.strings` OK |
| Localizzazioni | ✅ ESEGUITO | 580 chiavi per ciascun `Localizable.strings`; diff chiavi EN/ES/IT/ZH-Hans vuoto |
| `git diff --check` | ✅ ESEGUITO | PASS |
| Client condiviso | ✅ ESEGUITO | Unica creazione `SupabaseClient(` in `SupabaseClientProvider`; unico `SupabaseClientProvider(config:)` nel composition root |
| `makeClient` residuo | ✅ ESEGUITO | Nessun match in sorgenti/progetto/SPM resolved |
| Segreti/token | ✅ ESEGUITO | Match solo su guardrail `SupabaseConfig`, sanitizzazione e test sintetico; nessun token o segreto reale |
| Scritture remote/locali | ✅ ESEGUITO | Nessun `.insert/.update/.upsert/.delete/.rpc` nei file Supabase/Options; nessun `context.insert/delete/save` nel perimetro TASK-038 |
| Google/Firebase extra | ✅ ESEGUITO | Nessun `GoogleSignIn`/`Firebase` in sorgenti, progetto o `Package.resolved` |
| `SupabaseConfig.plist` locale | ✅ ESEGUITO | `git ls-files` vuoto; `git status --ignored` → `!! iOSMerchandiseControl/SupabaseConfig.plist` |
| `project.pbxproj` | ✅ ESEGUITO | Nessun diff finale; nessun riferimento a `SupabaseConfig.plist` reale |
| Release dev-only | ✅ ESEGUITO | Section auth/preview/diagnostica e sheet sotto `#if DEBUG`; Build Release PASS |

#### Configurazioni esterne residue

- Supabase Dashboard e Google Cloud OAuth risultano configurati a sufficienza per il test live registrato.
- Resta requisito operativo per ambienti futuri: mantenere Redirect URL Supabase `com.niwcyber.iosmerchandisecontrol://login-callback`, provider Google abilitato e client OAuth Google coerente.
- RLS owner-scoped e dataset devono rimanere verificati per account reali; errori di policy devono continuare a essere classificati come `permissionDeniedOrRLS`.

## Chiusura

### Conferma utente
- [x] Utente ha autorizzato esplicitamente la chiusura: se review OK dopo eventuali fix piccoli diretti, portare TASK-038 a `DONE` e riallineare MASTER-PLAN/backlog.

### Riepilogo finale
TASK-038 chiuso con esito **APPROVED_FIXED_DIRECTLY**: foundation Google OAuth Supabase iOS approvata dopo fix diretti di hardening config, microcopy e allineamento Supabase Swift 2.46.0 su `emitLocalSessionAsInitialSession` con guardia `session.isExpired`. Test live utente conferma login Google, redirect app, UI signed-in e dry-run Supabase auth-gated. Client condiviso session-aware, auth state machine, callback OAuth, listener, preview/diagnostica auth-gated, localizzazioni e URL scheme sono coerenti col planning. Nessun apply SwiftData, nessun push remoto, nessuna dipendenza Google/Firebase extra e nessun segreto reale introdotto.

### Data completamento
2026-05-05
