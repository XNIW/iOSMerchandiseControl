# TASK-143 — Mobile Storefront product control (iOS)

## Stato

- Stato: `INTEGRATED / VALIDATION_LIMITS_RECORDED`
- Fase: `REVIEW`
- Release train: `MOBILE_STOREFRONT_PRODUCT_CONTROL`
- Autorizzazione: prompt `USER_APPROVER` del 2026-08-21, valido per execution,
  review indipendente, PR, CI e merge quando tutti i gate tecnici sono verdi.
- Coordinator: Client `TASK-046`–`TASK-049`.

## Architecture map

- `Product`/SwiftData resta il dominio operativo e conserva il comportamento
  offline esistente.
- `Product.remoteID` UUID, insieme ad account e shop selezionato, è l'unico ponte
  verso la publication; barcode e testi non sono identità.
- Storefront publication resta server-authoritative nello stesso contratto
  Admin/Supabase, con `expectedVersion`, idempotency, RLS/RBAC, audit e source iOS
  legata alla sessione server.
- Il Client pubblico resta read-only e riceve soltanto la projection pubblica.

## File map

- `DatabaseView.swift`: badge, filtri e summary Storefront bounded; invalidazione
  editor su cambio account/shop; summary import senza mutazioni Storefront.
- `EditProductView.swift`: sezione compatta/espandibile "App clienti", preview,
  draft/publish/schedule/hide/archive, align esplicito, offline e conflict UI.
- `StorefrontAuthoring.swift`: DTO, RPC service sul trasporto Supabase esistente,
  store `@MainActor`, cache locale bounded e three-way conflict reapply.
- `ProductImages/*`: riuso upload/storage; adozione esplicita dell'immagine
  operativa come immagine pubblica senza automatismi.
- `iOSMerchandiseControlApp.swift`: dependency injection fail-closed.
- `*.lproj/Localizable.strings` e test mirati: localizzazione, accessibilità,
  async cancellation, account/shop switch, import e immagini.

## Contract map

- Read: `storefront_publications_authoring_read_v1`.
- Summary: `storefront_publications_authoring_summary_v1`, pagine max 100 e mai
  payload editor completo per la lista.
- Session source: `storefront_authoring_bind_ios_session_v1`, senza
  `mutationSource` controllabile dal client.
- Mutation: `storefront_publication_authoring_mutate_v1` per `save_draft`,
  `publish`, `schedule`, `hide`, `archive`; sempre con remote product UUID,
  shop, expected version, idempotency key e payload validato.
- Public image: pipeline Product Images corrente e adozione esplicita del
  version ID già finalizzato; nessun secondo stack di upload.

## Acceptance essenziale

- Editor operativo invariato; il relativo salvataggio non muta Storefront.
- Prodotto senza `remoteID` non pubblicabile e messaggio di sync esplicito.
- Prezzo operativo e pubblico distinti; align solo su azione utente; CLP intero.
- Cached read/local draft consentiti; publish/hide/schedule/price/image richiedono
  ACK di rete e non mostrano `published` prima della risposta server.
- Conflitti senza last-write-wins: base/draft/server, dirty fields reali, reload,
  reapply e cancel con nuovo `expectedVersion`.
- Account/shop switch cancella e invalida richieste/editor; nessuna callback dopo
  dismiss/deinit.
- Import operativo non pubblica e non altera publication; delete di published o
  scheduled richiede prima hide/archive.
- Public payload non contiene costo, margine, supplier, quantità esatta, note,
  audit/staff o identificatori tecnici non necessari.

## Gate

- Test mirati service/state/conflict/offline/image/import/scope/cancellation/UI,
  Dynamic Type e semantics.
- Suite canonica Xcode/Swift, build Release e simulator smoke se disponibile.
- Una review indipendente; un batch fix e una re-review al massimo, salvo nuovo
  P0/P1/P2 riproducibile causato dal fix.
- PR exact-SHA CI e merge normale soltanto con review e gate verdi.

## Handoff corrente

### Execution

- Implementato un solo editor prodotto: i campi operativi restano separati e la
  sezione compatta/espandibile `App clienti` appare per prodotti già salvati.
  Un prodotto salvato senza `remoteID` resta modificabile internamente ma mostra
  il gate di sincronizzazione e non può pubblicare.
- Lista Database con summary projection bounded, filtri Storefront e invalidazione
  account/shop; il filtro vuoto resta reversibile.
- Read/draft/publish/schedule/hide/archive sul contratto server condiviso, session
  source iOS legata server-side, `expectedVersion`, idempotency e ACK obbligatorio.
- Cache pubblica e draft locali account/shop scoped; reconnect con confronto
  versione e three-way reapply dei soli campi realmente diversi dalla base.
- Prezzo CLP pubblico distinto e align esplicito; mapping categoria per remote ID;
  import operativo preserva publication e produce solo il conteggio `needs_update`.
- Pipeline Product Images riusata per adozione e lettura WebP pubblica: host/path,
  image publication ID, variante, MIME, bytes, pixel e lifecycle sono bounded.
- Delete operativo fail-closed per `draft`, `scheduled` e `published`; è consentito
  soltanto senza publication o dopo `hide`/`archive`, senza mutazioni Storefront
  implicite dal save operativo o dall'import.

### Gate executor

- `git diff --check`: `PASS`.
- Test mirati Storefront service/state/offline/conflict/account-shop/image e UI
  Dynamic Type/semantics: `PASS`.
- Due test UI legacy di creazione prodotto hanno inizialmente fallito perché la
  card senza identity allungava il form; fix UX: authoring mostrato soltanto dopo
  il primo salvataggio. Rerun dei due test originali: `PASS`.
- Suite canonica Xcode post-fix: `1321 PASS`, `36 SKIP` opt-in, `0 FAIL`, bundle
  locale `/tmp/mc-ios-task143-gate-fixed.yEMtDh/full-tests.xcresult`.
- `xcodebuild analyze` Debug: `PASS_WITH_NOTES`; soli warning legacy in test non
  toccati e `Vendor 2/libxls`, nessun warning nuovo Storefront.
- Build Debug e Release Simulator `CODE_SIGNING_ALLOWED=NO`: `PASS`.
- `plutil -lint` EN/ES/IT/ZH: `PASS`; secret scan scoped: `PASS`.
- Simulator `TASK-139 iPhone 17` install/launch Release: `PASS`, PID osservato
  `17613`; UI suite esercita editor e harness Storefront reale.
- Device fisico e TestFlight non appartengono a questo handoff locale e saranno
  classificati nelle fasi di release train previste.

`CODEX_EXECUTION_COMPLETE_TO_REVIEW`

### Review indipendente

- Esito iniziale: `CHANGES_REQUIRED`, con `P0=0`, `P1=1`, `P2=4`, `P3=1`.
- Finding: mapping assente di `stale_revision`; replay reconnect senza idempotency
  key persistita; gate delete troppo restrittivo dopo hide/archive; preview immagine
  non ancora ACK sul valore server precedente; XCUITest limitato al solo prodotto
  non sincronizzato; cache editor `UserDefaults` senza bound.
- Slice indipendente del reviewer: `16/16 PASS`; nessun bypass RLS/RBAC, service
  role, token leak o cross-shop rilevato.

### Fix — unico batch

- `stale_revision` è ora un conflitto tipizzato con snapshot server.
- La draft `save_draft` persiste prima della rete una idempotency key stabile; al
  reconnect legge la versione server, replaya soltanto se invariata e riusa la
  stessa key. Publish/hide/schedule non vengono accodati offline.
- Delete operativo ammette soltanto publication assente, `hidden` o `archived`.
- L'immagine appena adottata è staged nella pipeline/cache immagini esistente e
  preview/thumbnail usano la candidata finché l'ACK authoring non la rende remota.
- La cache editor è LRU bounded a `24`; le pending draft restano separate e non
  vengono espulse.
- Harness UI DEBUG usa un prodotto salvato con remote identity e fake contract;
  gli XCUITest verificano campi reali, Dynamic Type, azioni, preview pubblica e
  conflitto. La preview usa una `NavigationLink` nel `NavigationStack` esistente.
- Gate del fix: Debug build `PASS`; test mirati `20 PASS / 0 FAIL`; XCUITest
  `2 PASS / 0 FAIL`; Release build `PASS`; `git diff --check`, localizzazioni e
  scan scoped `PASS`. La suite canonica precedente `1321/0` non è stata
  rieseguita perché già verde e il fix è coperto dalle slice mirate.

`CODEX_FIX_COMPLETE_TO_RE_REVIEW`

### Re-review indipendente

- Esito: `APPROVED`; `P0=0`, `P1=0`, `P2=0`, `P3=0`.
- Tutti i sei finding risultano risolti senza regressioni riproducibili.
- Evidence executor verificate: `20/20` unit/integration e `2/2` XCUITest.
- Slice autonoma reviewer: `5/5 PASS`, exit `0`, bundle locale
  `/tmp/mc-ios-task143-rereview-six.xcresult`.
- `git diff --check` e scan security scoped: `PASS`; worktree non modificato dal
  reviewer.

`CODEX_REVIEW_APPROVED_AWAITING_INTEGRATION`


### Riconciliazione F04 — 2026-09-28

Verifica corrente con `git fetch origin main`, `gh pr view 10` e `gh run list`:

- Implementazione: head PR `dbc4938d1cfe96803eeab37d45fefb46971d5856`.
- Integrazione: [PR #10](https://github.com/XNIW/iOSMerchandiseControl/pull/10) `MERGED` il 2026-08-21T21:00:43Z, merge `30d226d0fb9b8679a1dd034c6e82319645337f22`, attuale `origin/main` verificato il 2026-09-28.
- CI PR: [32524006454](https://github.com/XNIW/iOSMerchandiseControl/actions/runs/32524006454) `SUCCESS`; CI sul merge: [32526432062](https://github.com/XNIW/iOSMerchandiseControl/actions/runs/32526432062) `SUCCESS` sullo SHA esatto.
- Validazione: evidenze storiche locali sopra preservate; la CI storica non prova i nuovi scenari F01/F02/F03, ora in TASK-144. Device fisico/staging delle app non dichiarati verificati da questo riallineamento.
- Distribuzione: nessuna evidence nuova di TestFlight/App Store/production; `NOT_VERIFIED`, nessun deploy eseguito.

Handoff attuale: `INTEGRATED_ON_MAIN_VALIDATION_LIMITS_PRESERVED`; il vecchio `AWAITING_INTEGRATION` descriveva l'istantanea pre-merge. TASK-143 non è più la lane attiva e non viene dichiarato DONE per cancellare prove mancanti. Il solo task attivo è TASK-144.
