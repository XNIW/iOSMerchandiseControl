# TASK-122: iOS Sync Remote Domain Strangler and Final Architecture Purification

## Informazioni generali
- **Task ID**: TASK-122
- **Titolo**: iOS Sync Remote Domain Strangler and Final Architecture Purification
- **File task**: `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md`
- **Evidence dir**: `docs/TASKS/EVIDENCE/TASK-122/`
- **Stato**: DONE
- **Fase attuale**: CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING
- **Responsabile attuale**: USER / Accepted closure
- **Data creazione**: 2026-05-24
- **Ultimo aggiornamento**: 2026-05-25 10:11 -0400
- **Ultimo agente che ha operato**: CODEX / Tracking closure
- **Readiness**: CLOSED_DONE_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING. Local architecture execution accepted; later TASK-123 and canonical push resolved the practical closure path. No production-global claim.
- **Tipo task**: planning esecutivo architetturale iOS; nessuna nuova feature utente.
- **User override registrato**: l'utente ha richiesto nuova TASK-122 in PLANNING per supersedere TASK-121 sul blocker finale `Remote mega-service strangler`; con la closure del 2026-05-25, TASK-121 e TASK-122 sono entrambi DONE come catena storica della ristrutturazione sync iOS.

## LOCAL_CANONICAL_EXECUTION_OVERRIDE
L'utente ha autorizzato esplicitamente `LOCAL_CANONICAL_EXECUTION_OVERRIDE` per questa Execution. Per TASK-122 locale, local `HEAD` e working tree locale sono canonical operativi.

Questo override consente di non bloccare la refactor Swift locale solo perche' GitHub raw `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md` e' `404` o perche' il MASTER-PLAN remoto e' ancora centrato su TASK-121. Il mismatch remoto resta rischio residuo e deve essere riportato nel final handoff con:

```text
RESULT PASS_WITH_NOTES_LOCAL_CANONICAL_OVERRIDE
EXIT_CODE 0
NEXT_ACTION Remote GitHub canonical alignment still required after local REVIEW handoff; not blocking this local execution by explicit user override.
```

L'override non autorizza DONE, claim 100%, modifiche Kotlin, modifiche SQL/migration/RLS/grant/RPC/schema, Supabase live non sicuro, service_role client, bypass RLS, cleanup globale o cancellazione `auth.users`.

## Relazione con TASK-121
TASK-121 resta esplicitamente non DONE:

```text
TASK-121 — ACTIVE / FIX — CHANGES_REQUIRED / SUPERSEDED_BY_TASK-122_REMOTE_MEGA_SERVICE_BLOCKER
Non DONE. Root residues e vecchio SupabaseInventoryService.swift sono stati spostati/rimossi nel commit architetturale, ma Sync/Remote/SupabaseTransportClient.swift resta mega-service multi-domain da circa 1866 righe. TASK-122 supersede solo questo blocker finale.
```

Il MASTER-PLAN deve avere un solo task operativo corrente: `TASK-122 ACTIVE / PLANNING`. TASK-121 non deve essere marcato DONE, ARCHITECTURE_TARGET_MET o 100%.

## Verdetto review planning
Il piano e' corretto nella direzione: isola il blocker reale rimasto dopo TASK-121, cioe' `Sync/Remote/SupabaseTransportClient.swift` ancora mega-service multi-domain, e sposta il completamento in una task dedicata senza dichiarare TASK-121 DONE.

Il piano non e' pronto per EXECUTION finche' non sono integrati e provati:
- harness discovery.
- scanner TASK-122.
- fixture RED/GREEN.
- evidence README.
- MASTER-PLAN consistency.
- status taxonomy.
- report JSON validation.
- adapter ownership proof.
- call-site map.
- protocol conformance map.
- method responsibility map.
- Supabase read-only contract map.
- Android parity ledger.
- before/after architecture graph.

Verdetto operativo corrente: `TASK-122 ACTIVE / PLANNING`, non `REVIEW`, non `DONE`, non `ARCHITECTURE_TARGET_MET`.

## Nota canonical / local-only
Snapshot planning review 2026-05-24 19:14 -0400:
- local `HEAD`: `6cc042c5dede5b492734cc5a36c2c05a96e61b50`.
- local `origin/main`: `6cc042c5dede5b492734cc5a36c2c05a96e61b50`.
- `git ls-remote origin refs/heads/main`: `6cc042c5dede5b492734cc5a36c2c05a96e61b50`.
- GitHub raw `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md`: non visibile nel canonical raw durante questa review planning, quindi da trattare come `404` / local-only.
- GitHub raw `docs/MASTER-PLAN.md`: ancora TASK-121-only durante questa review planning.
- GitHub raw `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`: presente ma raw viewer ha restituito contenuto non affidabile/compresso per audit di dettaglio, quindi la futura execution deve usare anche commit-specific tree/raw e local file hash/LOC.
- GitHub raw `tools/agent/README.md`: presente ma canonical raw non prova ancora TASK-122 routing.
- GitHub API/raw per `tools/agent/lib`: deve essere verificata in execution con commit-specific tree e non solo con cache locale.

Conseguenza: TASK-122 e MASTER-PLAN sono al momento modifiche planning locali. Prima di qualsiasi patch Swift, move, split o delete, la futura EXECUTION deve provare che TASK-122, MASTER-PLAN ed evidence README sono visibili/coerenti tra local, origin/main e GitHub canonical main. Se GitHub raw del task resta `404`, se MASTER-PLAN remoto resta TASK-121-only, o se raw/commit-specific tree divergono, fermare la execution con:

```text
RESULT BLOCKED_EXTERNAL_HEAD_MISMATCH
EXIT_CODE 2
NEXT_ACTION Publish/align the planning docs to canonical main or rerun after origin/GitHub canonical converge; do not perform Swift moves/splits/deletes from a local-only plan.
```

Se la divergenza dipende da config errata, remote sbagliato, branch non canonical o evidence path non TASK-122, usare:

```text
RESULT MISCONFIGURED_HEAD_MISMATCH
EXIT_CODE 3
NEXT_ACTION Fix repo/remote/task/evidence configuration, then rerun head-consistency and raw canonical checks.
```

## Integrazione review ChatGPT 2026-05-24 — HARDENING_PLUS
Review aggiuntiva repo-grounded in sola modalita' Planning:
- GitHub raw conferma che `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md` non e' ancora canonical su `main` in questo momento: il task resta local-only finche' non e' pubblicato/allineato.
- GitHub raw `docs/MASTER-PLAN.md` e' ancora centrato su TASK-121, quindi TASK-122 non puo' entrare in Execution finche' `MASTER-PLAN` non diventa coerente con il task corrente.
- GitHub raw `tools/agent/README.md` conferma che `mc-agent.sh` e' l'entrypoint canonico e che MCP e' solo adapter sottile; quindi TASK-122 deve migliorare il harness invece di aggirarlo.
- GitHub raw `tools/agent/mc-agent.sh` conferma che il routing corrente non espone i nuovi scanner TASK-122 (`remote-transport-thin`, `adapter-delegation-depth`, `domain-method-ownership`, `manual-debug-boundary`, `transport-callsite-map`, `protocol-conformance-map`, `supabase-contract-map`, `android-parity-ledger`).
- GitHub raw degli adapter Remote conferma il problema architetturale reale: gli adapter sono wrapper pass-through verso `SupabaseTransportClient`, quindi non possiedono query/mapping/domain behavior.
- GitHub raw di `SupabaseTransportClient.swift` mostra anche un rischio di source-shape/source-format: contenuto enorme e/o visualizzato come poche linee molto lunghe. TASK-122 deve fallire se qualunque Swift sorgente resta minificato/flattened o non leggibile dagli scanner.

Decisione Planning:
- TASK-122 non deve limitarsi a split file-by-file.
- Prima di spostare logica Swift, deve rendere il harness capace di dimostrare: transport thin, zero domain conformance nel transport, adapter ownership reale, query ownership nei domain adapter, no pass-through puro, no source flattening, no concrete transport fuori Composition.
- `source-format` non e' un controllo cosmetico: e' un gate architetturale, perche' scanner, review e diff diventano inaffidabili se Swift e' compresso in righe giganti.
- Se un gate nuovo viene aggiunto, deve avere comando canonical, report, JSON, fixture RED/GREEN, discovery e CA collegato.

## Integrazione efficienza/100% claim guard — ChatGPT 2026-05-24
Questa integrazione chiarisce cosa significa completare TASK-122 rispetto alla domanda dell'utente: “dopo TASK-122 la sync iOS sara' 100% efficiente?”.

Verdetto di planning:
- TASK-122 e' una task architetturale P1: deve portare la sync iOS a una struttura quasi finale, pulita, misurabile e molto piu' vicina al target Android/Supabase.
- TASK-122 non autorizza automaticamente il claim “sync iOS 100% efficiente”, “100% production-ready”, “DONE” o “perfetta”.
- Anche se tutti gli hard gate architetturali passano, il massimo stato operativo resta `TASK-122 ACTIVE / REVIEW` finche' non esiste review approval + accettazione esplicita utente.
- Il claim “100% efficiente” e' vietato se live/account/device/cross-platform/offline/performance checks sono `NOT_RUN`, `BLOCKED_EXTERNAL`, coperti solo da fallback, oppure non hanno evidence machine-readable.
- Se TASK-122 completa transport thin, adapter ownership, protocol boundary, Composition boundary, scanner strict, build Debug/Release e regression tests, la valutazione ammessa nel final handoff e' “architettura sync iOS quasi finale / review-ready”, non “100% assoluto”.

Definizione pratica da usare nei report:
- `Architecture efficiency`: misura se la struttura e' corretta, modulare, senza mega-service, senza pass-through, senza concrete transport fuori Composition.
- `Runtime efficiency`: misura performance, paging/keyset, memoria, MainActor, retry, outbox, manual/automatic/recovery interaction.
- `Production readiness`: misura build/test/smoke, dati reali, account/device/live, offline, conflitti, timestamp, sicurezza e regressioni cross-platform.
- `100% user claim`: ammesso solo se tutte e tre le dimensioni sopra sono PASS, senza criteri hard in `NOT_RUN` o `PASS_WITH_NOTES`, e dopo accettazione esplicita utente.

TASK-122 deve quindi produrre una `sync-efficiency-acceptance-matrix` che dica chiaramente:
- cosa e' stato provato come PASS;
- cosa e' stato provato solo come fallback;
- cosa e' `NOT_RUN` o `BLOCKED_EXTERNAL`;
- quali limiti residui impediscono di dichiarare 100%;
- se serve una TASK successiva, ad esempio TASK-123, per final live/cross-platform/offline acceptance.

Regola anti-claim:
```text
Se live/account/device/cross-platform/offline/performance acceptance non sono tutti PASS con evidence, non dichiarare “100% efficiente”.
Dichiarare invece: “TASK-122 ha portato la sync iOS a REVIEW architetturale; restano acceptance/live checks prima del claim 100%”.
```

## Obiettivo
Trasformare `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift` da mega-service multi-domain a transport sottile e spostare la logica reale nei domain adapter/service corretti, preservando equivalenza funzionale con il comportamento iOS corrente e con il riferimento Android.

Target del transport sottile:
- Supabase client/session/account access.
- Shared request execution helpers.
- Shared error mapping.
- Redaction/privacy-safe logging helpers solo se realmente infrastrutturali.
- Nessuna business logic catalog/product-price/history/session/sync-event/outbox/manual/debug/dry-run/recovery.
- Nessuna mutazione SwiftData `ModelContext`.
- Nessuna ownership retry automatico.
- Nessun lavoro UI/MainActor.
- Nessun metodo gigante domain-specific.

## Stato attuale iOS
Snapshot statico iniziale del 2026-05-24:
- `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`: 1866 righe, ancora mega-service multi-domain.
- Adapter Remote esistenti:
  - `Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
  - `Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
  - `Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
  - `Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`
- Root sync-related Swift vietati osservati a livello `iOSMerchandiseControl/`: nessun `SupabaseInventoryService.swift`; restano solo auth/config/provider root:
  - `SupabaseAuthService.swift`
  - `SupabaseAuthViewModel.swift`
  - `SupabaseClientProvider.swift`
  - `SupabaseConfig.swift`
- Architettura attuale: adattamento misto tra nuova struttura e vecchio monolite Remote.
- Review planning 2026-05-24: gli adapter Remote letti localmente sono pass-through puri verso `SupabaseTransportClient`:
  - `CatalogRemoteSupabaseAdapter` inoltra create/update supplier/category/product al transport.
  - `ProductPriceRemoteSupabaseAdapter` inoltra insert ProductPrice al transport.
  - `HistorySessionRemoteSupabaseAdapter` inoltra upsert/fetch sessioni al transport.
  - `SyncEventRemoteSupabaseAdapter` inoltra fetch sync_events/catalog/product_prices/session/counts al transport.
- Harness attuale letto localmente:
  - `mc-agent.sh` non ha routing TASK-122.
  - `tools/agent/lib/common.sh` espone ancora `MC_AGENT_VERSION="0.4.0-task120"`.
  - `tools/agent/mcp/server.mjs` allowlista task fino a TASK-121, non TASK-122.
  - `task119_scans.py`, `task120_scans.py`, `task121_scans.py` esistono ma TASK-122 richiede modulo dedicato o generic task-aware esplicito.

## Riferimento Android usato
Android locale: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.

Uso ammesso:
- riferimento funzionale per ProductPrice paging/keyset, catalog push/pull, history/session sync, sync_events/outbox, manual sync behavior, import/export side effects.
- ledger di parita' con evidenze e differenze intenzionali.

Uso vietato:
- copiare Kotlin in Swift.
- modificare Android senza override esplicito.
- trattare Android come fonte schema write o come autorizzazione a cambiare feature utente.

## Riferimento Supabase read-only da usare
Supabase locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase`.

Uso ammesso in TASK-122:
- contract read-only.
- table/column/RPC usage map.
- confronto con DTO/query e policy attese solo in lettura.

Uso vietato:
- Supabase live write.
- cleanup live.
- migration.
- RLS/grant/RPC/schema change.
- service_role client, bypass RLS, secrets.

## Differenze trovate
Differenze gia' note da TASK-121 review:
- root residues e vecchio `SupabaseInventoryService.swift` sono stati spostati/rimossi nel commit architetturale.
- `Sync/Remote/SupabaseTransportClient.swift` resta multi-domain e supera la soglia accettabile.
- gli adapter Remote sono presenti ma prevalentemente deleganti; il possesso reale di query/mapping/domain behavior non e' dimostrato.
- scanner precedente `sync-architecture` aveva falso negativo; TASK-122 deve impedire ritorno del mega-service anche con rename o delega opaca.

Differenze da completare in EXECUTION-AUDIT:
- call-site map completa di `SupabaseTransportClient`.
- protocol conformance map.
- method responsibility map.
- adapter-to-table/column/RPC map.
- Android parity ledger completo.
- Xcode membership before/after.
- before/after architecture graph.
- regression risk map.

## Cosa cambia per l'utente
Nulla intenzionalmente:
- nessuna nuova feature utente.
- nessuna modifica UI salvo microcopy/error state minima necessaria a preservare comportamento.
- Options status deve restare equivalente.
- manual sync regression, automatic sync, ProductPrice paging, history/session sync, catalog sync, outbox/sync_events, recovery/full pull devono restare equivalenti.

## Cosa NON cambia funzionalmente
- ProductPrice keyset paging/chunking.
- Catalog push/pull behavior.
- History/session sync.
- sync_events/outbox behavior.
- Manual sync behavior.
- Import/export side effects.
- Account/session semantics.
- Supabase schema, policy, grants, RPC e dati live.
- User-visible feature set.
- TASK-122 non cambia il significato di `DONE`: non basta l'Execution per dichiarare sync iOS 100% efficiente, production-ready o completa senza acceptance finale.

## Target architettura finale
Adapter/service finali minimi:
- `Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
- `Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
- `Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
- `Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`
- `Sync/Remote/SupabaseTransportClient.swift` solo thin transport.
- `Sync/Manual/...` per manual-only debug/dry-run/push/pull.
- `Sync/Recovery/...` per full pull/recovery.
- `Sync/Automatic/...` per automatic planner/writer/reader orchestration.
- `Sync/Shared/...` solo value types, DTO puri, mapper puri e helper puri.

Regole ownership:
- Catalog remote behavior posseduto da catalog adapter/service.
- ProductPrice remote behavior posseduto da product price adapter/service e conserva keyset paging/chunking.
- History/session remote behavior posseduto da history adapter/service.
- SyncEvent/outbox remote behavior posseduto da sync event adapter/service.
- Manual/dry-run/debug isolato sotto `Sync/Manual` o debug-only boundary esplicito.
- Recovery/full-pull isolato sotto `Sync/Recovery`.
- Automatic runtime usa protocolli/domain writers/readers e non importa concrete Supabase transport fuori da Composition.
- Manual sync non contamina Automatic.
- Shared resta puro, senza SwiftData, UI, networking, concrete Supabase.

## Boundary architetturali aggiuntivi obbligatori
Questi boundary completano il target architetturale e devono essere verificati da scanner, non solo da review manuale:

### Transport protocol boundary
- `SupabaseTransportClient` non deve conformare protocolli domain-specific come `SyncAutomaticIncrementalRemote`, `SupabaseInventoryFetching`, `SupabaseProductPriceKeysetFetching`, `SupabaseProductPriceManualPushRemoteAccessing`, `SupabaseProductPricePushDryRunRemoteFetching`, `OptionsSyncRemoteCountFetching` o equivalenti.
- Ammessa solo eventuale interfaccia infrastrutturale minima, ad esempio accesso client/session/error mapping, se giustificata e testata.
- Se una conformance serve solo a preservare call-site temporanei, non e' accettabile per REVIEW: va spostata su adapter/service domain.

### Composition boundary
- Concrete `SupabaseTransportClient` puo' essere istanziato/iniettato solo in Composition/DI o Remote adapter construction.
- `Sync/Automatic/**` deve dipendere da protocolli domain (`CatalogRemote...`, `ProductPriceRemote...`, `HistorySessionRemote...`, `SyncEventRemote...`) e non dal concrete transport.
- `Sync/Manual/**` e `Sync/Recovery/**` non devono riusare Automatic come scorciatoia nascosta; condividono solo DTO/helper puri.

### Adapter ownership boundary
- Ogni adapter deve possedere almeno una delle responsabilita' reali: query Supabase, DTO mapping, pagination/keyset, owner guard, read-back validation, error mapping domain-specific o table/RPC contract.
- Adapter con metodi `try await remote.sameMethod(...)` sono pass-through e devono fallire `adapter-delegation-depth`.
- Per ProductPrice, la proof deve coprire keyset/paging/chunking e non solo insert/upsert singolo.

### Debug/test-seed boundary
- Metodi DEBUG/TASK seed/collision/probe non possono restare dentro il transport thin.
- Devono essere spostati in `Sync/Manual`, `Sync/TestSupport`, `Sync/Diagnostics` o modulo equivalente esplicitamente escluso dal runtime automatico.
- Nessun seed/debug live write deve essere disponibile senza gate `MC_ALLOW_LIVE=1`, prefix task-scoped e report redatto.

### Source-shape/source-format boundary
- Swift file minificati, flattened o con righe giganti rendono scanner e review non affidabili.
- Prima di audit architetturale e prima di Swift split/move/delete, `source-format` o `swift-source-shape` deve provare:
  - newline/indentation leggibili;
  - nessun file Swift domain-critical in una singola riga enorme;
  - nessuna perdita semantica durante la formattazione;
  - diff reviewabile e Xcode membership stabile.
- Se la formattazione richiede patch Swift, va trattata come pre-refactor scoped cleanup, con build/check dedicato e senza cambiare comportamento.

### DTO/query mapper ownership
- DTO puri possono restare in Remote/Shared solo se non importano SwiftData/UI e non contengono networking concreto.
- Query mapper/RPC mapper devono avere owner chiaro: Catalog, ProductPrice, HistorySession, SyncEvent, Manual o Recovery.
- Duplicazioni DTO/query mapper tra Remote, Manual e Recovery devono fallire `dto-mapper-duplication` o essere documentate come eccezione temporanea con review date.


## File iOS da toccare
EXECUTION deve partire da inventory, non da questa lista come autorizzazione cieca. File candidate:
- `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
- `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/SupabaseInventoryDTOs.swift`
- `iOSMerchandiseControl/Sync/Remote/SupabaseSyncEventDTOs.swift`
- `iOSMerchandiseControl/Sync/Remote/SyncEventRPCRequestMapper.swift`
- `iOSMerchandiseControl/Sync/Manual/**` solo per manual/debug/dry-run ownership.
- `iOSMerchandiseControl/Sync/Recovery/**` solo per recovery/full-pull ownership.
- `iOSMerchandiseControl/Sync/Automatic/**` solo per protocol wiring/composition and no concrete transport outside composition.
- `iOSMerchandiseControl/Sync/Shared/**` solo per pure DTO/value/helper relocation.
- Xcode project membership only as needed after file moves/splits/deletes.

Non toccare senza override:
- Kotlin Android.
- SQL/migrations/RLS/grants/RPC/schema.
- Supabase live data.
- UI fuori da microcopy/error state necessaria.

## Inventory harness e automazioni
Disponibile e da riusare:
- `./tools/agent/mc-agent.sh` come unico entrypoint.
- `tools/agent/lib/common.sh`.
- `tools/agent/lib/report.sh`.
- `tools/agent/lib/redact.sh`.
- `tools/agent/lib/ios.sh`.
- `tools/agent/lib/supabase.sh`.
- `tools/agent/lib/sync.sh`.
- `tools/agent/mcp/server.mjs`.
- scanner storici `sync_architecture_scans.py`, `task117_scans.py`, `task119_scans.py`, `task120_scans.py`, `task121_scans.py` solo se task-aware, non hardcoded su altri task, e con evidence TASK-122.

Da creare o migliorare prima dell'uso come gate:
- `tools/agent/lib/task122_scans.py` oppure modulo task-aware equivalente e visibile.
- `tools/agent/fixtures/task122_scanners/`.
- routing in `mc-agent.sh`.
- discovery `help-json` / `list commands-json`.
- MCP wrapper allowlist per comandi safe TASK-122.
- JSON schema validation per report TASK-122.
- redazione centralizzata per token, JWT, email, path personali, device id, project ref, query sensibili.

Regole:
- se un comando canonico esiste, va usato.
- se manca un comando ripetibile, va creato nel harness.
- se esiste ma e' fragile, rumoroso, senza exit code affidabile, senza report o senza `NEXT_ACTION`, va migliorato prima di usarlo come gate.
- nessun workaround manuale ripetibile deve rimanere fuori harness quando il comando esiste o deve essere creato.

## P0 canonical GitHub/head gate
La futura EXECUTION deve iniziare con:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-122
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-122
./tools/agent/mc-agent.sh config validate --task TASK-122
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json
./tools/agent/mc-agent.sh scan task-docs --task TASK-122 --strict
./tools/agent/mc-agent.sh scan master-plan-consistency --task TASK-122 --strict
./tools/agent/mc-agent.sh scan evidence-metadata --task TASK-122 --strict
```

Controllo no-cache obbligatorio:
- local HEAD.
- origin/main.
- GitHub canonical main.
- commit-specific tree.
- GitHub raw per vecchi root files e nuovi Remote files.

Se qualunque controllo diverge:
- bloccare Swift moves/splits/deletes.
- status `BLOCKED_EXTERNAL_HEAD_MISMATCH` o `MISCONFIGURED_HEAD_MISMATCH`.
- evidence con `NEXT_ACTION`.
- nessun workaround locale.

Questi gate devono provare:
- MASTER-PLAN ha TASK-122 come unico task operativo corrente.
- TASK-121 resta non DONE e superseded/blocked solo per Remote mega-service.
- evidence README TASK-122 esiste.
- evidence TASK-122 non viene scritta fuori da `docs/TASKS/EVIDENCE/TASK-122/`.
- TASK-122 file, MASTER-PLAN ed evidence README sono coerenti tra local, origin/main, GitHub canonical main, commit-specific tree e GitHub raw.
- se TASK-122 e' local-only o GitHub raw e' `404`, execution si ferma prima di Swift patch con `BLOCKED_EXTERNAL_HEAD_MISMATCH` o `MISCONFIGURED_HEAD_MISMATCH`.

## Tassonomia stati, exit code e claim
Status canonici:
- `PASS`
- `FAIL`
- `BLOCKED_EXTERNAL`
- `MISCONFIGURED`
- `UNSAFE_OPERATION_REFUSED`
- `NOT_RUN`
- `PASS_WITH_NOTES`

Exit code canonici:
- `0`: `PASS`
- `1`: `FAIL`
- `2`: `BLOCKED_EXTERNAL`
- `3`: `MISCONFIGURED`
- `4`: `UNSAFE_OPERATION_REFUSED`

Regole claim:
- `NOT_RUN` non conta mai come `PASS`.
- `PASS_WITH_NOTES` non puo' chiudere criteri hard: architettura, build, strict scanners, sensitive, evidence, schema read-only, no-live-write.
- vietato dichiarare `DONE`, `100%`, `ARCHITECTURE_TARGET_MET`.
- massimo handoff consentito a Codex in execution/fix: `TASK-122 ACTIVE / REVIEW`.
- `DONE` solo dopo review approval + accettazione esplicita utente.
- ogni report deve includere `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION`.

## Audit obbligatorio prima di refactor Swift
1. Sync inventory file-by-file con categorie `Automatic`, `Manual`, `Recovery`, `Remote`, `Shared`, `Composition`, `Tests`, `Uncategorized`; nessun file puo' restare `Uncategorized`.
2. Root inventory file-by-file di residues `Supabase*.swift`, `*Sync*.swift`, `*Outbox*.swift`.
3. Complete call-site map di `SupabaseTransportClient`.
4. Protocol conformance map completa.
5. Method responsibility map per ogni metodo del transport: catalog, product price, history, sync event, manual, debug, dry-run, recovery, shared transport.
6. Adapter ownership proof con delegation-depth.
7. Supabase table/column/RPC map read-only.
8. Android parity ledger per ProductPrice paging/keyset, catalog push/pull, history/session, sync_events/outbox, manual sync, import/export side effects.
9. Xcode membership before/after.
10. Before/after architecture graph.
11. Regression risk map.
12. Acceptance criteria evidence index.

## Scanner/gate da creare
Non nascondere logica TASK-122 in scanner TASK-119/TASK-120/TASK-121 opachi. Creare `tools/agent/lib/task122_scans.py` oppure modulo generico task-aware visibile.

Scanner/gate obbligatori e comandi canonici:

```bash
./tools/agent/mc-agent.sh scan sync-architecture --task TASK-122 --strict
./tools/agent/mc-agent.sh scan remote-transport-thin --task TASK-122 --strict
./tools/agent/mc-agent.sh scan adapter-delegation-depth --task TASK-122 --strict
./tools/agent/mc-agent.sh scan domain-method-ownership --task TASK-122 --strict
./tools/agent/mc-agent.sh scan manual-debug-boundary --task TASK-122 --strict
./tools/agent/mc-agent.sh scan sync-inventory --task TASK-122 --strict
./tools/agent/mc-agent.sh scan transport-callsite-map --task TASK-122 --strict
./tools/agent/mc-agent.sh scan protocol-conformance-map --task TASK-122 --strict
./tools/agent/mc-agent.sh scan supabase-contract-map --task TASK-122 --strict --read-only
./tools/agent/mc-agent.sh scan android-parity-ledger --task TASK-122 --strict
./tools/agent/mc-agent.sh scan xcode-membership --task TASK-122 --strict
./tools/agent/mc-agent.sh scan dead-code --task TASK-122 --strict
./tools/agent/mc-agent.sh scan source-format --task TASK-122 --strict
./tools/agent/mc-agent.sh scan sensitive --task TASK-122 --strict
./tools/agent/mc-agent.sh scan evidence --task TASK-122 --strict
./tools/agent/mc-agent.sh scan mcp-wrapper --task TASK-122 --strict
./tools/agent/mc-agent.sh report validate-json --task TASK-122 --path docs/TASKS/EVIDENCE/TASK-122/agent-runs
```

Scanner aggiuntivi da creare come comandi separati o subcheck strict documentati:
```bash
./tools/agent/mc-agent.sh scan swift-source-shape --task TASK-122 --strict
./tools/agent/mc-agent.sh scan transport-protocol-conformance --task TASK-122 --strict
./tools/agent/mc-agent.sh scan composition-import-boundary --task TASK-122 --strict
./tools/agent/mc-agent.sh scan remote-query-ownership --task TASK-122 --strict
./tools/agent/mc-agent.sh scan debug-seed-boundary --task TASK-122 --strict
./tools/agent/mc-agent.sh scan dto-mapper-duplication --task TASK-122 --strict
./tools/agent/mc-agent.sh scan supabase-query-map --task TASK-122 --strict --read-only
./tools/agent/mc-agent.sh scan sync-efficiency-acceptance --task TASK-122 --strict
```

Questi scanner possono essere implementati dentro `task122_scans.py` o come subcomandi task-aware, ma devono apparire in discovery e avere fixture RED/GREEN come gli altri.

Ogni scanner deve avere:
- report `.log`, `.md`, `.json`.
- `RESULT`.
- `EXIT_CODE`.
- `REPORT_MD`.
- `REPORT_JSON`.
- `NEXT_ACTION`.
- redazione centralizzata.
- fixture RED/GREEN.
- expected exit code.
- expected JSON status.
- README/manifest fixture.

Fixture RED/GREEN obbligatorie:
- directory `tools/agent/fixtures/task122_scanners/`.
- ogni scanner nuovo con fixture RED/GREEN, expected JSON status, expected exit code, README/manifest con scenario, comando, expected result, `NEXT_ACTION`.
- `transport mega-service renamed`.
- `transport > 500 LOC`.
- `adapter pass-through puro`.
- `domain method nel transport`.
- `manual/debug importato da Automatic`.
- `file sync non categorizzato`.
- `concrete Supabase transport importato fuori Composition`.
- `report con dato sensibile non redatto`.

Discovery/MCP:
- ogni comando deve apparire in `help-json` e `list commands-json`.
- MCP wrapper aggiornato e testato per ogni comando safe.
- nessun comando manuale lungo se esiste harness canonico.

## Execution ordering da pianificare
1. HEAD/preflight/config.
2. `help-json` / `list commands-json`.
3. Canonical TASK-122 / MASTER-PLAN / evidence README check.
4. `task-docs` / `master-plan-consistency` / `evidence-metadata`.
5. `harness-routing` / `harness-health` / `mcp-wrapper`.
6. `source-format`.
7. Scanner TASK-122 creation/routing.
8. Fixture RED/GREEN.
9. Scanner self-tests.
10. `sync-inventory`.
11. Call-site/protocol/method responsibility audit.
12. Android parity ledger.
13. Supabase read-only contract map.
14. Swift split/move/delete plan.
15. Solo dopo questi PASS, Swift split/move/delete.
16. Xcode membership.
17. Scanner matrix.
18. Debug/Release build.
19. Targeted/broad tests.
20. Options smoke/fallback.
21. Sensitive/evidence/report validation.
22. Before/after architecture map.
23. Final handoff `TASK-122 ACTIVE / REVIEW`.

## Matrice test/build/smoke
Ogni riga in execution evidence deve includere:
- comando canonico.
- report MD.
- report JSON.
- exit code.
- owner.
- `NEXT_ACTION` se non `PASS`.
- motivazione se `PASS_WITH_NOTES` o `NOT_RUN`.

Build:
- `./tools/agent/mc-agent.sh ios build debug --task TASK-122`
- `./tools/agent/mc-agent.sh ios build release --task TASK-122`
- no duplicate symbols.
- no stale/deleted file referenced by build/tests/Xcode project.

Scanner:
- `source-format`.
- `swift-source-shape`.
- `sync-inventory`.
- `sync-architecture`.
- `remote-transport-thin`.
- `adapter-delegation-depth`.
- `domain-method-ownership`.
- `manual-debug-boundary`.
- `transport-protocol-conformance`.
- `composition-import-boundary`.
- `remote-query-ownership`.
- `debug-seed-boundary`.
- `dto-mapper-duplication`.
- `supabase-query-map`.
- `sync-efficiency-acceptance`.
- `transport-callsite-map`.
- `protocol-conformance-map`.
- `supabase-contract-map`.
- `android-parity-ledger`.
- `xcode-membership`.
- `dead-code`.
- `sensitive`.
- `evidence`.
- JSON report validation.
- `mcp-wrapper`.

Tests:
- usare solo comandi canonici scoperti da `help-json` / `list commands-json`.
- non ricostruire `xcodebuild` manuale se il harness copre il caso.
- automatic architecture tests.
- automatic domain tests.
- broad sync tests.
- manual sync regression tests.
- ProductPrice paging/keyset regression tests.
- History/session sync regression tests.
- catalog sync regression tests.
- sync_events/outbox regression tests.

Smoke/contract:
- Options smoke PASS o `BLOCKED_EXTERNAL` con fallback accettato, ma non contato come live proof.
- Supabase contract read-only PASS.
- no Supabase live write/cleanup/migration/RLS/grant/RPC/schema.
- no service_role client, no RLS bypass, no secrets.
- live/account/device checks `NOT_RUN` o `BLOCKED_EXTERNAL` salvo autorizzazione esplicita `MC_ALLOW_LIVE=1`.
- cleanup execute vietato salvo override esplicito; dry-run solo con prefix `TASK122_*` e cleanup plan id.

Efficiency/acceptance:
- `sync-efficiency-acceptance` PASS obbligatorio per REVIEW.
- La matrix deve separare `Architecture efficiency`, `Runtime efficiency`, `Production readiness` e `100% user claim`.
- Se live/account/device/cross-platform/offline/performance checks sono `NOT_RUN`, `BLOCKED_EXTERNAL` o `PASS_WITH_NOTES`, il final handoff deve dichiarare esplicitamente che TASK-122 non autorizza il claim “100% efficiente”.
- Se questi controlli richiedono autorizzazione live o device non disponibile, registrarli come limiti residui e proporre una task successiva di final acceptance, senza bloccare la review architetturale se tutti gli hard gate TASK-122 sono PASS.

## Evidence output obbligatoria
File richiesti:
- `docs/TASKS/EVIDENCE/TASK-122/README.md`
- `docs/TASKS/EVIDENCE/TASK-122/planning-review-integration.md`
- `docs/TASKS/EVIDENCE/TASK-122/agent-runs/*.log`
- `docs/TASKS/EVIDENCE/TASK-122/agent-runs/*.md`
- `docs/TASKS/EVIDENCE/TASK-122/agent-runs/*.json`
- `docs/TASKS/EVIDENCE/TASK-122/sync-inventory.md`
- `docs/TASKS/EVIDENCE/TASK-122/sync-inventory.json`
- `docs/TASKS/EVIDENCE/TASK-122/sync-inventory.csv`
- `docs/TASKS/EVIDENCE/TASK-122/transport-callsite-map.md`
- `docs/TASKS/EVIDENCE/TASK-122/transport-callsite-map.json`
- `docs/TASKS/EVIDENCE/TASK-122/protocol-conformance-map.md`
- `docs/TASKS/EVIDENCE/TASK-122/protocol-conformance-map.json`
- `docs/TASKS/EVIDENCE/TASK-122/method-responsibility-map.md`
- `docs/TASKS/EVIDENCE/TASK-122/method-responsibility-map.json`
- `docs/TASKS/EVIDENCE/TASK-122/adapter-ownership-proof.md`
- `docs/TASKS/EVIDENCE/TASK-122/adapter-ownership-proof.json`
- `docs/TASKS/EVIDENCE/TASK-122/supabase-contract-map-readonly.md`
- `docs/TASKS/EVIDENCE/TASK-122/supabase-contract-map-readonly.json`
- `docs/TASKS/EVIDENCE/TASK-122/android-parity-ledger.md`
- `docs/TASKS/EVIDENCE/TASK-122/android-parity-ledger.json`
- `docs/TASKS/EVIDENCE/TASK-122/xcode-membership-before-after.md`
- `docs/TASKS/EVIDENCE/TASK-122/xcode-membership-before-after.json`
- `docs/TASKS/EVIDENCE/TASK-122/before-after-architecture-map.md`
- `docs/TASKS/EVIDENCE/TASK-122/regression-risk-map.md`
- `docs/TASKS/EVIDENCE/TASK-122/acceptance-criteria-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-122/acceptance-criteria-matrix.json`
- `docs/TASKS/EVIDENCE/TASK-122/final-handoff.md`
- `docs/TASKS/EVIDENCE/TASK-122/source-shape-report.md`
- `docs/TASKS/EVIDENCE/TASK-122/source-shape-report.json`
- `docs/TASKS/EVIDENCE/TASK-122/transport-protocol-conformance.md`
- `docs/TASKS/EVIDENCE/TASK-122/transport-protocol-conformance.json`
- `docs/TASKS/EVIDENCE/TASK-122/composition-import-boundary.md`
- `docs/TASKS/EVIDENCE/TASK-122/composition-import-boundary.json`
- `docs/TASKS/EVIDENCE/TASK-122/remote-query-ownership.md`
- `docs/TASKS/EVIDENCE/TASK-122/remote-query-ownership.json`
- `docs/TASKS/EVIDENCE/TASK-122/debug-seed-boundary.md`
- `docs/TASKS/EVIDENCE/TASK-122/debug-seed-boundary.json`
- `docs/TASKS/EVIDENCE/TASK-122/dto-mapper-duplication.md`
- `docs/TASKS/EVIDENCE/TASK-122/dto-mapper-duplication.json`
- `docs/TASKS/EVIDENCE/TASK-122/fingerprint-index.json`
- `docs/TASKS/EVIDENCE/TASK-122/sync-efficiency-acceptance-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-122/sync-efficiency-acceptance-matrix.json`
- `docs/TASKS/EVIDENCE/TASK-122/live-validation-limitations.md`
- `docs/TASKS/EVIDENCE/TASK-122/performance-baseline-before-after.md`
- `docs/TASKS/EVIDENCE/TASK-122/performance-baseline-before-after.json`
- `docs/TASKS/EVIDENCE/TASK-122/post-task122-next-step-recommendation.md`

Fingerprint obbligatori:
- SHA o hash stabile di `TASK-122`, `MASTER-PLAN`, `mc-agent.sh`, `tools/agent/lib/**`, `tools/agent/mcp/server.mjs`, `SupabaseTransportClient.swift` e adapter Remote before/after.
- Ogni report JSON deve includere `canonicalHead`, `localHead`, `originHead`, `githubHead`, `taskId`, `scannerName`, `startedAt`, `finishedAt`, `status`, `exitCode`, `nextAction`, `redactionSummary`.

## Performance invariants
- ProductPrice keyset paging non deve peggiorare.
- Nessun full in-memory mega snapshot nuovo.
- Preserve chunking/page size salvo evidence.
- No heavy work su MainActor.
- No UI `ModelContext` nel background automatic path.
- Manual/debug/dry-run non deve bloccare automatic runtime.
- Runtime responsive, no UI `Task.sleep` retry.
- Performance baseline before/after deve essere documentato per dataset realistico o dichiarato `BLOCKED_EXTERNAL` con motivo e next action.
- Nessun claim di miglioramento performance e' ammesso senza misurazione o prova indiretta verificabile dai test/scanner.

## Rischi di regressione
- TASK-122 local-only non allineato a GitHub.
- MASTER-PLAN remoto ancora su TASK-121.
- scanner nuovi non discoverable.
- report JSON non validabili.
- `PASS_WITH_NOTES` usato per criteri hard.
- redazione incompleta di path personali/project ref/email/token/device id.
- ProductPrice paging/chunking degradato durante spostamento query.
- Adapter apparentemente nuovi ma ancora deleganti al transport.
- adapter nuovi ma ancora pass-through.
- Duplicazione DTO/query mapper tra Remote, Manual, Recovery.
- Automatic path che importa concrete Supabase transport fuori da Composition.
- Automatic che importa concrete transport fuori Composition.
- Manual/debug/dry-run che rientra in runtime automatico.
- Shared contaminato da networking/SwiftData/UI.
- Xcode project con file rimossi o membership mancante.
- Scanner troppo permissivi o task-routing opaco.
- Transport che resta conformante ai protocolli domain anche se i metodi sono spostati.
- DEBUG/TASK seed methods rimasti nel transport e quindi non separati dal runtime.
- Swift source flattening/minificazione che rende falsi positivi/negativi gli scanner.
- LOC metric ingannevole se misurata da raw GitHub compresso invece che da sorgente locale normalizzato.
- DTO/query mapper duplicati o divergenti tra Remote, Manual e Recovery.
- Supabase `.from(...)` / `.rpc(...)` usage non mappato, con regressioni schema nascoste.
- Build PASS ma architettura FAIL per conformance/import boundary non rispettati.
- Claim “100% efficiente” fatto dopo una sola refactor architetturale senza live/cross-platform/offline/performance acceptance.
- Final handoff che confonde `REVIEW` con `DONE`.
- TASK-122 che passa architetturalmente ma lascia `NOT_RUN` hard acceptance senza dichiarare limiti residui.
- Performance dichiarata migliorata senza baseline before/after o dataset realistico.

## Acceptance criteria
- **CA-122-01**: TASK-122 file e evidence README creati.
- **CA-122-02**: MASTER-PLAN aggiornato con TASK-122 come unico task operativo corrente.
- **CA-122-03**: TASK-121 marcato non DONE e superseded/blocked solo per remote mega-service blocker.
- **CA-122-04**: HEAD/preflight/config/discovery pianificati come gate obbligatori.
- **CA-122-05**: `sync-inventory` TASK-122 produce Markdown/JSON/CSV e nessun file resta `UNCATEGORIZED`.
- **CA-122-06**: source-format PASS prima di qualunque move/split/delete.
- **CA-122-07**: call-site map completa per `SupabaseTransportClient`.
- **CA-122-08**: method responsibility map completa per tutti i metodi del transport.
- **CA-122-09**: adapter-to-table/column/RPC map read-only Supabase presente.
- **CA-122-10**: Android parity ledger presente per ProductPrice paging/keyset, History/session, catalog sync, sync_events/outbox, manual sync, import/export side effects.
- **CA-122-11**: `SupabaseTransportClient.swift` ridotto a thin transport con soglia massima documentata: preferibile < 300 LOC, hard fail > 500 LOC salvo eccezione approvata con owner/test/review date.
- **CA-122-12**: nessun metodo domain-specific catalog/product-price/history/sync-event/manual/debug nel transport.
- **CA-122-13**: Catalog remote behavior posseduto da catalog adapter/service.
- **CA-122-14**: ProductPrice remote behavior posseduto da product price adapter/service e conserva keyset paging/chunking.
- **CA-122-15**: History/session remote behavior posseduto da history adapter/service.
- **CA-122-16**: SyncEvent/outbox remote behavior posseduto da sync event adapter/service.
- **CA-122-17**: Manual/dry-run/debug behavior isolato sotto `Sync/Manual` o debug-only boundary esplicito.
- **CA-122-18**: Recovery/full-pull behavior isolato sotto `Sync/Recovery`.
- **CA-122-19**: Automatic runtime non importa concrete Supabase transport fuori da Composition.
- **CA-122-20**: Manual sync non contamina Automatic.
- **CA-122-21**: Shared resta puro, senza SwiftData, UI, networking, concrete Supabase.
- **CA-122-22**: Sync root non contiene provider monolith, runtime owner, retry ownership, manual residues o compat legacy non approvato.
- **CA-122-23**: no duplicate symbols.
- **CA-122-24**: no stale/deleted file referenced by build/tests/Xcode project.
- **CA-122-25**: scanner `sync-architecture --task TASK-122 --strict` fallisce se `SupabaseTransportClient` torna mega-service anche sotto altro nome.
- **CA-122-26**: scanner `remote-transport-thin --task TASK-122 --strict` creato con fixture RED/GREEN.
- **CA-122-27**: scanner `adapter-delegation-depth --task TASK-122 --strict` creato con fixture RED/GREEN: fail se adapter delega tutto al transport senza possedere query/mapping/domain behavior.
- **CA-122-28**: scanner `domain-method-ownership --task TASK-122 --strict` creato con fixture RED/GREEN.
- **CA-122-29**: scanner `manual-debug-boundary --task TASK-122 --strict` creato con fixture RED/GREEN.
- **CA-122-30**: scanner `xcode-membership --task TASK-122 --strict` PASS.
- **CA-122-31**: scanner `dead-code --task TASK-122 --strict` PASS.
- **CA-122-32**: scanner `source-format --task TASK-122 --strict` PASS.
- **CA-122-33**: scanner `sensitive` e `evidence` PASS.
- **CA-122-34**: report JSON validation PASS.
- **CA-122-35**: iOS Debug build PASS.
- **CA-122-36**: iOS Release build PASS.
- **CA-122-37**: automatic architecture tests PASS.
- **CA-122-38**: automatic domain tests PASS.
- **CA-122-39**: broad sync tests PASS.
- **CA-122-40**: manual sync regression tests PASS.
- **CA-122-41**: ProductPrice paging/keyset regression tests PASS.
- **CA-122-42**: History/session sync regression tests PASS.
- **CA-122-43**: catalog sync regression tests PASS.
- **CA-122-44**: sync_events/outbox regression tests PASS.
- **CA-122-45**: Options smoke PASS o BLOCKED_EXTERNAL con accepted fallback, ma non contato come live proof.
- **CA-122-46**: Supabase contract read-only PASS.
- **CA-122-47**: no Supabase live write/cleanup/migration/RLS/grant/RPC/schema.
- **CA-122-48**: no service_role client, no RLS bypass, no secrets.
- **CA-122-49**: no user-visible feature change.
- **CA-122-50**: before/after architecture map prova net simplification reale, non solo rename.
- **CA-122-51**: final handoff solo `TASK-122 ACTIVE / REVIEW`, mai DONE.
- **CA-122-52**: DONE solo dopo review approval + accettazione esplicita utente.
- **CA-122-53**: TASK-122/Master Plan/evidence README coerenti local/origin/GitHub oppure BLOCKED/MISCONFIGURED con NEXT_ACTION.
- **CA-122-54**: tutti i nuovi scanner discoverable via help-json/list commands-json.
- **CA-122-55**: ogni scanner nuovo ha fixture RED/GREEN con expected exit code/status.
- **CA-122-56**: ogni report include RESULT/EXIT_CODE/REPORT_MD/REPORT_JSON/NEXT_ACTION.
- **CA-122-57**: status taxonomy rispettata; NOT_RUN/PASS_WITH_NOTES non chiudono criteri hard.
- **CA-122-58**: evidence index collega ogni CA al report che la prova.
- **CA-122-59**: redaction scan prova assenza di token/JWT/password/email complete/path personali/device id/project ref non redatti.
- **CA-122-60**: nessun workaround manuale ripetibile resta fuori harness se il comando esiste o doveva essere creato.
- **CA-122-61**: `swift-source-shape --task TASK-122 --strict` PASS e prova che i file Swift critici non sono minificati/flattened e sono reviewabili.
- **CA-122-62**: `transport-protocol-conformance --task TASK-122 --strict` PASS e prova che `SupabaseTransportClient` non conforma piu' protocolli domain/automatic/manual/options.
- **CA-122-63**: `composition-import-boundary --task TASK-122 --strict` PASS e prova che concrete transport e' usato solo in Composition/DI o adapter construction.
- **CA-122-64**: `remote-query-ownership --task TASK-122 --strict` PASS e prova che gli adapter possiedono query/mapping/domain behavior, non solo pass-through.
- **CA-122-65**: `debug-seed-boundary --task TASK-122 --strict` PASS e prova che metodi DEBUG/TASK seed/collision/probe non restano nel transport thin.
- **CA-122-66**: `dto-mapper-duplication --task TASK-122 --strict` PASS o eccezioni documentate con owner, motivazione e review date.
- **CA-122-67**: `supabase-query-map --task TASK-122 --strict --read-only` PASS e mappa ogni `.from(...)`, `.rpc(...)`, `.insert`, `.upsert`, `.update`, `.delete`, table, column e RPC usata dal codice Swift coinvolto.
- **CA-122-68**: `SupabaseTransportClient.swift` conserva solo client/session/error/shared request helpers e nessun DEBUG seed, diagnostic live write o table-specific query.
- **CA-122-69**: ProductPrice keyset/chunking e read-back validation sono provati nel nuovo owner ProductPrice, con evidence prima/dopo.
- **CA-122-70**: History/session paging e by-ID fetch sono provati nel nuovo owner HistorySession, con evidence prima/dopo.
- **CA-122-71**: SyncEvent/outbox incremental fetch e entity lookup sono provati nel nuovo owner SyncEvent, con evidence prima/dopo.
- **CA-122-72**: Catalog supplier/category/product create/update/fetch ownership e owner guard sono provati nel nuovo owner Catalog, con evidence prima/dopo.
- **CA-122-73**: fingerprint-index JSON collega hash before/after dei file critici a ogni report scanner/build/test.
- **CA-122-74**: nessun scanner TASK-122 puo' PASSare usando solo nomi file; deve analizzare contenuto/metodi/import/conformance o dichiarare `MISCONFIGURED`.
- **CA-122-75**: REVIEW e' ammesso solo se tutti i criteri hard architetturali, source-shape, scanner strict, build Debug/Release, sensitive/evidence e no-live-write sono PASS; `PASS_WITH_NOTES` ammesso solo su smoke esterni non hard.
- **CA-122-76**: `sync-efficiency-acceptance --task TASK-122 --strict` PASS e produce matrix Markdown/JSON con `Architecture efficiency`, `Runtime efficiency`, `Production readiness` e `100% user claim`.
- **CA-122-77**: il final handoff vieta esplicitamente claim “100% efficiente” se qualunque controllo live/account/device/cross-platform/offline/performance resta `NOT_RUN`, `BLOCKED_EXTERNAL` o `PASS_WITH_NOTES`.
- **CA-122-78**: performance baseline before/after presente o `BLOCKED_EXTERNAL` con `NEXT_ACTION`; nessun claim performance senza evidence.
- **CA-122-79**: ProductPrice keyset/chunking ha proof di no-regression runtime, non solo proof architetturale.
- **CA-122-80**: manual sync, automatic sync e recovery/full-pull interaction sono validati o dichiarati come limite residuo con owner e next task.
- **CA-122-81**: cross-platform iOS/Android/Supabase acceptance matrix presente; se live non autorizzato, la matrix resta `BLOCKED_EXTERNAL` e impedisce il claim 100%.
- **CA-122-82**: offline/outbox/conflict/timestamp behavior ha test/evidence o limite residuo dichiarato; nessun claim production-ready se non coperto.
- **CA-122-83**: final handoff separa chiaramente “architettura sync iOS review-ready” da “sync iOS 100% production-ready”.
- **CA-122-84**: se restano limiti live/device/offline/performance, `post-task122-next-step-recommendation.md` propone una TASK successiva focalizzata su final acceptance, non su ulteriore refactor cosmetica.
- **CA-122-85**: il claim “100% efficiente” puo' essere scritto solo dopo DONE approval + accettazione esplicita utente + tutti i hard acceptance PASS.

## Check finali
Check obbligatori in future EXECUTION/FIX:
- Build compila: iOS Debug e Release.
- Nessun warning nuovo introdotto, se verificabile dal build log.
- Modifiche coerenti con planning.
- Criteri di accettazione verificati uno per uno.
- Scanner/harness discovery salvati in evidence.
- No live write/cleanup/schema/RLS/grant/RPC.
- Handoff finale completo verso Claude.
- Handoff finale include sezione `Efficiency / 100% claim guard` con verdict esplicito: `REVIEW architetturale`, `non 100%`, oppure `100% claim eligible` solo se CA-122-76..85 PASS.

## Prompt EXECUTION-AUDIT futuro
Usare questo prompt come ingresso per il futuro executor, dopo approvazione planning:

```text
Esegui TASK-122 in EXECUTION seguendo docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md.
Prima di qualsiasi Swift patch, tratta TASK-122 come task harness+evidence+architecture-gate. Nessuna patch Swift finche' HEAD, MASTER-PLAN, evidence README, discovery harness, scanner TASK-122, fixture RED/GREEN e audit maps non sono PASS o correttamente BLOCKED/MISCONFIGURED con NEXT_ACTION.

Gate P0:
1. ./tools/agent/mc-agent.sh git head-consistency --task TASK-122
2. ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-122
3. ./tools/agent/mc-agent.sh config validate --task TASK-122
4. ./tools/agent/mc-agent.sh help-json
5. ./tools/agent/mc-agent.sh list commands-json
6. ./tools/agent/mc-agent.sh scan task-docs --task TASK-122 --strict
7. ./tools/agent/mc-agent.sh scan master-plan-consistency --task TASK-122 --strict
8. ./tools/agent/mc-agent.sh scan evidence-metadata --task TASK-122 --strict
9. ./tools/agent/mc-agent.sh scan swift-source-shape --task TASK-122 --strict
10. ./tools/agent/mc-agent.sh scan transport-protocol-conformance --task TASK-122 --strict
11. ./tools/agent/mc-agent.sh scan composition-import-boundary --task TASK-122 --strict
12. ./tools/agent/mc-agent.sh scan remote-query-ownership --task TASK-122 --strict
13. ./tools/agent/mc-agent.sh scan debug-seed-boundary --task TASK-122 --strict
14. ./tools/agent/mc-agent.sh scan dto-mapper-duplication --task TASK-122 --strict
15. ./tools/agent/mc-agent.sh scan supabase-query-map --task TASK-122 --strict --read-only
16. ./tools/agent/mc-agent.sh scan sync-efficiency-acceptance --task TASK-122 --strict

Se TASK-122 e' local-only, GitHub raw del task e' 404, MASTER-PLAN remoto e' ancora TASK-121-only, oppure HEAD/origin/GitHub canonical/raw divergono, ferma Swift moves/splits/deletes e registra BLOCKED_EXTERNAL_HEAD_MISMATCH o MISCONFIGURED_HEAD_MISMATCH con NEXT_ACTION.

Poi completa, con evidence Markdown/JSON/CSV dove richiesto:
- task-docs/master-plan-consistency/evidence-metadata
- harness-routing/harness-health/mcp-wrapper
- source-format + swift-source-shape
- scanner TASK-122 routing + RED/GREEN fixture + self-tests
- report JSON validation
- sync-inventory file-by-file senza UNCATEGORIZED
- call-site/protocol/method responsibility audit del transport
- adapter ownership proof
- Android parity ledger
- Supabase read-only table/column/RPC map
- sync-efficiency-acceptance matrix: separa architettura review-ready da 100% production-ready
- solo dopo questi PASS, esegui split/move/delete Swift minimo necessario.

Non patchare Kotlin/SQL, non fare build/test runtime prima della fase prevista, non fare Supabase live/write/cleanup/migration/RLS/grant/RPC/schema change, non pushare GitHub, non dichiarare DONE, 100% o “sync iOS 100% efficiente”.
Final handoff solo TASK-122 ACTIVE / REVIEW e includi eventuali limiti residui + proposta TASK successiva se live/cross-platform/offline/performance acceptance non e' completamente PASS.
```

## Prompt futuro per estendere il planning
Usare questo prompt per futuri raffinamenti solo planning:

```text
Resta esclusivamente in PLANNING su docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md.
Leggi task, MASTER-PLAN, harness, MCP e GitHub canonical/raw prima di modificare.
Distingui strumenti esistenti, mancanti e fragili.
Per ogni nuovo gate aggiungi: comando harness, report .md/.json/.log, fixture RED/GREEN, discovery help-json/list commands-json, MCP policy se safe, acceptance criterion, risk e evidence path.
Se il nuovo gate riguarda efficienza, performance, live, offline o cross-platform, aggiorna anche `sync-efficiency-acceptance-matrix`, CA-122-76..85 e il divieto di claim 100% senza evidence.
Non patchare Swift/Kotlin/SQL, non eseguire build/test runtime, non fare Supabase live/write/cleanup/migration/RLS/grant/RPC/schema change, non pushare GitHub.
Output massimo: planning integrato. Non promuovere a EXECUTION, REVIEW o DONE.
```

## Handoff planning
TASK-122 e' in PLANNING. Serve review/integrazione Claude prima della promozione a EXECUTION. Codex non ha eseguito patch Swift/Kotlin/SQL, build/test runtime, Supabase live/write/cleanup/migration/RLS/grant/RPC/schema change o push GitHub in questo turno.

La domanda “dopo TASK-122 la sync iOS sara' 100% efficiente?” e' stata integrata come guardrail di planning: TASK-122 puo' rendere la sync iOS architetturalmente quasi finale e review-ready, ma il claim 100% richiede CA-122-76..85, live/cross-platform/offline/performance acceptance quando autorizzata, review approval e accettazione esplicita utente.

## Execution — Codex 2026-05-24
### Obiettivo compreso
Portare TASK-122 da PLANNING verso execution end-to-end fino a massimo `ACTIVE / REVIEW`, creando prima harness/scanner/evidence e solo dopo, se i gate P0 e audit lo consentono, procedendo al refactor Swift del Remote mega-service.

### File controllati
- `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md`
- `docs/MASTER-PLAN.md`
- `tools/agent/README.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/report.sh`
- `tools/agent/lib/redact.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/supabase.sh`
- `tools/agent/lib/sync.sh`
- `tools/agent/mcp/server.mjs`
- `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
- Remote adapters Catalog/ProductPrice/HistorySession/SyncEvent.

### Piano minimo applicato
1. Eseguire P0 head/preflight/config/discovery.
2. Correggere routing scanner TASK-122 nel harness prima di qualunque Swift.
3. Rilanciare gate evidence/harness.
4. Eseguire canonical raw no-cache.
5. Fermare Swift refactor se TASK-122 resta local-only o GitHub canonical non allineato.

### Modifiche fatte
- Creato `tools/agent/lib/task122_scans.py` per scanner TASK-122 read-only/content-based.
- Aggiornato routing `tools/agent/mc-agent.sh` per scanner TASK-122.
- Aggiornato discovery `tools/agent/lib/common.sh` con comandi TASK-122.
- Aggiornato MCP allowlist `tools/agent/mcp/server.mjs` con comandi safe TASK-122.
- Aggiunte fixture placeholder RED/GREEN sotto `tools/agent/fixtures/task122_scanners/`.
- Salvate discovery `00-help-json.json` e `00-commands-json.json` in evidence TASK-122.
- Salvato canonical raw/head check in `docs/TASKS/EVIDENCE/TASK-122/canonical-raw-head-check.md/json`.
- Nessuna patch Swift/Kotlin/SQL eseguita.

### Check eseguiti
- ✅ ESEGUITO — `git head-consistency --task TASK-122`: PASS (`20260524T233730Z-git-head-consistency-task-TASK-122-p17153`).
- ✅ ESEGUITO — `preflight --require-head-consistency --task TASK-122`: PASS (`20260524T233738Z-preflight-require-head-consistency-task-TASK-122-p17732`).
- ✅ ESEGUITO — `config validate --task TASK-122`: PASS (`20260524T233746Z-config-validate-task-TASK-122-p18432`).
- ✅ ESEGUITO — `help-json` / `list commands-json`: salvati in `agent-runs/00-help-json.json` e `agent-runs/00-commands-json.json`.
- ✅ ESEGUITO — `scan task-docs --task TASK-122 --strict`: PASS (`20260524T233754Z-scan-task-docs-task-TASK-122-strict-p18955`).
- ✅ ESEGUITO — `scan master-plan-consistency --task TASK-122 --strict`: PASS (`20260524T233758Z-scan-master-plan-consistency-task-TASK-122-strict-p19446`).
- ❌ ESEGUITO — primo `scan evidence-metadata --task TASK-122 --strict`: FAIL per routing TASK-120 errato (`20260524T233802Z-scan-evidence-metadata-task-TASK-122-strict-p19937`).
- ✅ ESEGUITO — dopo fix harness, `scan evidence-metadata --task TASK-122 --strict`: PASS (`20260524T234526Z-scan-evidence-metadata-task-TASK-122-strict-p22557`).
- ✅ ESEGUITO — `scan harness-routing --task TASK-122 --strict`: PASS (`20260524T234620Z-scan-harness-routing-task-TASK-122-strict-p25338`).
- ✅ ESEGUITO — `scan harness-health --task TASK-122 --strict`: PASS (`20260524T234537Z-scan-harness-health-task-TASK-122-strict-p23083`).
- ✅ ESEGUITO — `scan mcp-wrapper --task TASK-122 --strict`: PASS (`20260524T234537Z-scan-mcp-wrapper-task-TASK-122-strict-p23136`).
- ✅ ESEGUITO — `scan scanner-self-tests --task TASK-122 --strict`: PASS (`20260524T234537Z-scan-scanner-self-tests-task-TASK-122-strict-p23145`).
- ❌ ESEGUITO — canonical raw/head check: `BLOCKED_EXTERNAL_HEAD_MISMATCH`; TASK-122 raw GitHub = `404`, remote MASTER-PLAN raw = TASK-121-only. Evidence `canonical-raw-head-check.md/json`.
- ⚠️ NON ESEGUIBILE — Swift split/move/delete: bloccato dal canonical mismatch.
- ⚠️ NON ESEGUIBILE — build/test runtime: bloccati perche' Swift refactor non puo' iniziare.
- ⚠️ NON ESEGUIBILE — Supabase live/write/cleanup/migration/RLS/grant/RPC/schema: non eseguiti e non necessari prima del blocker.

### Rischi rimasti
- TASK-122 e MASTER-PLAN sono local-only rispetto a GitHub raw canonical.
- I nuovi scanner TASK-122 sono routing/harness-ready ma non sono ancora stati usati per autorizzare refactor Swift.
- Il Remote mega-service resta invariato finche' il canonical blocker non viene risolto.

### Handoff post-execution
`TASK-122 BLOCKED / BLOCKED_EXTERNAL_HEAD_MISMATCH`, non REVIEW, non DONE.

NEXT_ACTION: pubblicare/allineare `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md`, `docs/MASTER-PLAN.md`, `docs/TASKS/EVIDENCE/TASK-122/README.md` e harness TASK-122 su GitHub canonical `main`; poi rieseguire P0 head/raw/discovery e riprendere execution dai gate scanner/audit. Nessun workaround locale e nessuna patch Swift sono consentiti finche' TASK-122 resta raw `404` o MASTER-PLAN remoto resta TASK-121-only.

## Execution — Codex 2026-05-24 LOCAL_CANONICAL_EXECUTION_OVERRIDE completion
### Obiettivo compreso
L'utente ha autorizzato esplicitamente `LOCAL_CANONICAL_EXECUTION_OVERRIDE`: la divergenza GitHub raw resta evidence/rischio, ma non blocca la refactor Swift locale. Obiettivo eseguito: portare TASK-122 fino a `ACTIVE / REVIEW` locale, non DONE, senza claim 100%.

### File controllati
- `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
- `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Recovery/RecoveryRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- harness TASK-122 e test iOS rilevanti.

### Piano minimo applicato
1. Registrare override locale nei tracking docs.
2. Completare/irrobustire harness TASK-122 e scanner.
3. Produrre audit/mappe/evidence.
4. Rifattorizzare Swift spostando query/domain behavior dal transport agli adapter.
5. Rieseguire scanner matrix, Debug/Release build e test canonici.
6. Aggiornare handoff a REVIEW locale.

### Modifiche fatte
- `SupabaseTransportClient.swift` ridotto a 136 LOC: client/session/error mapping e probe infrastrutturale.
- Rimosse conformance domain dal transport.
- Catalog/ProductPrice/HistorySession/SyncEvent adapter possiedono query Supabase/domain behavior.
- Aggiunto `SupabaseRemoteQueryExecutor` come helper Remote generico di esecuzione query.
- Aggiunto `RecoveryRemoteSupabaseAdapter` per full-pull/recovery preview senza riportare domain protocol sul transport.
- Composition/UI aggiornata per passare adapter corretti a Options e preview service.
- Test legacy aggiornati per usare adapter al posto del transport monolitico.
- Harness scanner TASK-122 corretto per falsi positivi su fixture, URL SwiftPM e local override.

### Check eseguiti
- ✅ ESEGUITO — P0 local head/preflight/config/discovery: PASS.
- ✅ ESEGUITO — Debug build: PASS (`20260525T002109Z-ios-build-debug-task-TASK-122-p89855`).
- ✅ ESEGUITO — Release build: PASS (`20260525T000555Z-ios-build-release-task-TASK-122-p79346`).
- ✅ ESEGUITO — automatic architecture tests: PASS (`20260525T001034Z-ios-test-automatic-architecture-task-TASK-122-p84477`).
- ✅ ESEGUITO — automatic domain tests: PASS (`20260525T001051Z-ios-test-automatic-domain-task-TASK-122-p85127`).
- ✅ ESEGUITO — broad sync tests: PASS (`20260525T001759Z-ios-test-sync-task-TASK-122-p88346`).
- ✅ ESEGUITO — manual sync regression tests: PASS (`20260525T002049Z-ios-test-manual-sync-regression-task-TASK-122-p89236`).
- ✅ ESEGUITO — final scanner matrix TASK-122: PASS, inclusi `remote-transport-thin`, `adapter-delegation-depth`, `domain-method-ownership`, `composition-import-boundary`, `remote-query-ownership`, `xcode-membership`, `sensitive`, `evidence`.
- ✅ ESEGUITO — report JSON validation: PASS (`20260525T002203Z-report-validate-json-task-TASK-122-path-docs-TASKS-EVIDENCE-TASK-122-agent-runs-p89854`).
- ⚠️ NON ESEGUIBILE — live/account/device/cross-platform/offline/performance acceptance: non eseguita in questa execution locale; resta requisito per 100% claim.
- ✅ ESEGUITO — Supabase contract locale/read-only scan: PASS; nessuna modifica SQL/schema/RLS/grant/RPC/migration.

### Rischi rimasti
- GitHub raw TASK-122 resta non allineato: `PASS_WITH_NOTES_LOCAL_CANONICAL_OVERRIDE`, next action post-handoff.
- Live Supabase/device/account non provati in questa fase.
- Claim “sync iOS 100% efficiente” non eleggibile senza CA-122-76..85 tutti PASS, review approval e accettazione esplicita utente.

### Handoff post-execution
`TASK-122 ACTIVE / REVIEW` locale. Responsabile: `CLAUDE / Reviewer`. Non DONE, non `ARCHITECTURE_TARGET_MET`, non 100%.

## Review — Codex 2026-05-24 post-implementation
### Obiettivo compreso
Eseguire review completa e repo-grounded dell'implementazione TASK-122 locale, senza dichiarare DONE, senza claim 100%, senza production-ready e senza riaprire refactor cosmetiche. Correggere solo problemi reali supportati da evidence.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md`
- `docs/TASKS/EVIDENCE/TASK-122/final-handoff.md`
- matrix/evidence TASK-122 richieste dal prompt
- `tools/agent/README.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/task122_scans.py`
- `tools/agent/lib/common.sh`
- `tools/agent/mcp/server.mjs`
- `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
- `iOSMerchandiseControl/Sync/Remote/SupabaseRemoteQueryExecutor.swift`
- adapter Remote Catalog/ProductPrice/HistorySession/SyncEvent
- `iOSMerchandiseControl/Sync/Recovery/RecoveryRemoteSupabaseAdapter.swift`
- Composition/Options/preview/test compatibility call sites rilevanti

### Piano minimo applicato
1. Leggere tracking, evidence, harness e codice coinvolto.
2. Audit manuale architettura/efficienza/boundary/security.
3. Rerun scanner matrix TASK-122 canonica.
4. Rerun build/test canonici.
5. Verificare Supabase locale read-only e mantenere live/device/offline/cross-platform come external gate.
6. Aggiornare tracking/evidence solo con risultati di review.

### Modifiche fatte
- Nessun fix Swift/Kotlin/SQL necessario: non sono emersi problemi P0/P1/P2 reali da correggere nel codice.
- Aggiornate evidence/tracking TASK-122 con i run di review piu' recenti.
- Rigenerati report generati dagli scanner `performance-baseline`, `offline-outbox-conflict`, `sync-efficiency-acceptance` e `report validate-json`.
- Conservati `Production readiness BLOCKED_EXTERNAL` e `100% production claim NOT_ELIGIBLE`.

### Check eseguiti
- ✅ ESEGUITO — Review manuale transport: `SupabaseTransportClient.swift` 117 LOC, nessuna `.from(...)`, `.rpc(...)`, `.insert`, `.upsert`, `.update`, `.delete`, nessuna conformance domain, nessun `ModelContext`, nessun UI/MainActor.
- ✅ ESEGUITO — Review manuale executor/adapter: `SupabaseRemoteQueryExecutor` e' helper generico; query/domain ownership resta negli adapter Remote; ProductPrice keyset/chunking/read-back behavior preservato.
- ✅ ESEGUITO — Scanner matrix TASK-122: PASS per source-format, swift-source-shape, sync-inventory, sync-architecture, remote-transport-thin, adapter-delegation-depth, domain-method-ownership, manual-debug-boundary, transport-protocol-conformance, composition-import-boundary, remote-query-ownership, debug-seed-boundary, dto-mapper-duplication, supabase-query-map, performance-baseline, sync-efficiency-acceptance, xcode-membership, dead-code, sensitive, evidence, report validate-json. Latest final validation: `20260525T010246Z-report-validate-json-task-TASK-122-path-docs-TASKS-EVIDENCE-TASK-122-agent-runs-p26942`.
- ✅ ESEGUITO — Debug build: PASS (`20260525T005428Z-ios-build-debug-task-TASK-122-p1984`).
- ✅ ESEGUITO — Release build: PASS (`20260525T005439Z-ios-build-release-task-TASK-122-p2686`).
- ✅ ESEGUITO — automatic architecture tests: PASS (`20260525T005550Z-ios-test-automatic-architecture-task-TASK-122-p3472`).
- ✅ ESEGUITO — automatic domain tests: PASS (`20260525T005611Z-ios-test-automatic-domain-task-TASK-122-p4138`).
- ✅ ESEGUITO — broad sync tests: PASS (`20260525T005619Z-ios-test-sync-task-TASK-122-p4660`).
- ✅ ESEGUITO — manual sync regression tests: PASS (`20260525T005858Z-ios-test-manual-sync-regression-task-TASK-122-p5436`).
- ✅ ESEGUITO — Supabase local read-only status/schema/RLS/grants: PASS (`20260525T005918Z`, `20260525T005920Z`, `20260525T005927Z`, `20260525T005929Z`).
- ⚠️ NON ESEGUIBILE — offline/outbox/conflict runtime device acceptance: `BLOCKED_EXTERNAL` (`20260525T010014Z-scan-offline-outbox-conflict-task-TASK-122-strict-p8552`); richiede device/account/sessione autenticata e dati `TASK122_*`.
- ⚠️ NON ESEGUIBILE — cross-platform Android/device live acceptance: `BLOCKED_EXTERNAL`; `adb` non disponibile in questa shell, nessuna modifica Kotlin.
- ⚠️ NON ESEGUIBILE — live scoped Supabase write/account acceptance: non eseguita per assenza di safety gate/sessione live; nessun dato `TASK122_*` creato.

### Rischi rimasti
- GitHub raw/canonical alignment resta `PASS_WITH_NOTES_LOCAL_CANONICAL_OVERRIDE` da allineare dopo handoff.
- Live/device/offline/cross-platform acceptance restano external gate, quindi production readiness resta `BLOCKED_EXTERNAL`.
- Performance runtime resta `PASS_WITH_NOTES`: baseline corrente misurata, ma nessun before comparabile autorizza claim di miglioramento.
- `RecoveryRemoteSupabaseAdapter` resta volutamente sottile sopra gli adapter catalog/product-price; gli scanner e la review non hanno trovato regressione concreta, ma la ownership recovery runtime completa resta da validare nei gate live/offline.

### Handoff post-review
`TASK-122 ACTIVE / REVIEW — REVIEW_CONFIRMED`.

Verdict:
```text
Architecture efficiency PASS.
Runtime efficiency PASS_WITH_NOTES.
Production readiness BLOCKED_EXTERNAL.
100% production claim NOT_ELIGIBLE.
DONE not allowed pending explicit user acceptance and live/offline/cross-platform completion.
```

NEXT_ACTION: Claude/user review finale; poi allineare GitHub canonical e completare acceptance esterna live/offline/cross-platform con safety gate `MC_ALLOW_LIVE=1`, account autenticato e prefisso `TASK122_*`.

## Chiusura finale per override utente — 2026-05-25 10:11 -0400
L'utente ha richiesto esplicitamente di chiudere in DONE gli ultimi task bloccati/superseded della ristrutturazione sync iOS. Questa chiusura e' documentale e di workflow: conserva la cronologia, non inventa nuovi gate, non modifica codice runtime, non cambia policy conflict/merge, non introduce service_role client, non bypassa RLS e non dichiara production globale 100%.

Esito closure: DONE / CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING.

Motivazione: la catena TASK-115...122 e' stata superata dalla successiva evidenza architetturale/runtime e dalla chiusura TASK-123, che valida il perimetro simulator iOS 26.4 <-> Android Emulator <-> Supabase live/dev same-account autosync speed. I blocker storici live/device/manual/account rimangono note di perimetro, non gate aperti per questi task chiusi.

NEXT_ACTION: nessuna per questa catena di ristrutturazione sync iOS. Non dichiarare production globale; aprire un nuovo task separato solo per coperture future real-device, long background/locked, long offline, conflitti complessi o multi-account policy.
