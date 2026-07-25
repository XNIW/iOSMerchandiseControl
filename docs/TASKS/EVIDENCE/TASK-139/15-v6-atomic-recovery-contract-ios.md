# TASK-139 — iOS V6: recovery atomico e contratto sync-event

Data: `2026-07-23`

Verdict lane iOS: `REVIEW_WITH_IOS_V6_ATOMIC_RECOVERY_VERIFIED_ISOLATED / REVIEW`.

Questo è il checkpoint iOS autorevole successivo alla FIX del 2026-07-21. Non
è una chiusura globale di TASK-139: non è stato eseguito un nuovo replace E2E
su account/staging autorizzato né una prova Admin–Android–iOS con dati reali.

## Root cause e correzione locale

Il finding runtime originario era un evento legacy con `changed_count > 0` ma
entity ID insufficienti: Diagnostics lo riportava come
`sync_event_missing_entity_ids`. La policy fail-closed lo ha bloccato
correttamente; la lacuna era che il candidato non poteva poi certificare il
superamento dell'evento con un recovery completo e durevole.

L'audit diretto della migration Admin V6 ha inoltre trovato quattro mismatch
nel candidato precedente alla run finale: digest per righe newline anziché
catena incrementale, identity prodotto senza `item_number`, prezzo ricostruito
dal `Double` anziché da `price_canonical`, e digest JSON di history non
consumati. Senza queste correzioni un recovery poteva restare bloccato oppure
non dimostrare la convergenza; non era lecito convertirlo in `noWork`.

La correzione usa esclusivamente il contratto V6 congelato:

- bigint/cursor sul wire sono stringhe decimali canoniche, mai JSON number;
- scope opaco account/shop/device e fence di checkpoint sono validati a ogni
  boundary asincrono;
- la pagina eventi è limitata a `150`, il recovery usa i limiti V6
  `240/240/60/120/3/240`, i targeted fetch `60/60/60/120/3/240` e payload
  massimo `4 MiB`;
- un evento applicabile con ID entità assenti, vuoti, duplicati o di dominio
  incoerente richiede recovery durevole; non viene trasformato in `noWork` e
  non avanza il watermark;
- il watermark avanza solo insieme alla fence V6 autorizzata dal server; un
  errore di persistenza della fence conserva il watermark locale.

L'allineamento aggiuntivo alla migration reale usa la seed SHA-256 vuota e,
per ogni riga ordinata, `previousHex + U+001F + lunghezza UTF-8 + ':' + valore`.
Il client ora include il digest dell'`item_number`, rifiuta relazioni vive su
un product tombstone, conserva il tipo prezzo raw (`PURCHASE`/`RETAIL`) nel
digest pur validandone la semantica, usa il decimale canonico server per la
materializzazione e richiede i due digest redatti della history. Payload
incompleti o non canonici falliscono prima della publication.

Le 58 failure della prima full suite V6 sono state conservate come storico. Non
erano una tolleranza del decoder: erano fixture pre-V6 con `id` JSON numerico.
Le factory dei test sono state convertite a stringhe decimali; il decoder
production resta intenzionalmente fail-closed sui numeri JSON.

## Boundary di pubblicazione atomico

La generazione attiva non viene modificata durante il download. La sequenza
effettiva è:

1. checkpoint A e download paginato in una generation SwiftData separata;
2. chiusura ledger e receipt locale; capture della mutation fence pre-B;
3. checkpoint B monotono e confronto di count, ID set e digest del receipt;
4. tail eventi A→B, con entity ID completi, poi verifica della fence pre-B;
5. baseline e verifica nel solo staging con checkpoint B;
6. capture della fence finale, marker di convergenza e publication del manifest;
7. fsync della famiglia SQLite/WAL, ledger e directory, rename atomico del
   manifest, read-back e finalization journal prima del clear del recovery.

Una mutazione dello staging durante B/tail fa fallire la fence e quarantena la
generation; non può diventare parte del database visibile. Un crash prima del
rename lascia selezionata G-old; un crash dopo il rename seleziona G-new
durabile. Cleanup e retention sono bounded/idempotenti e non riusano staging
quarantinati.

## Prova crash/relaunch reale, isolata

È stato eseguito `tools/agent/task139_atomic_generation_crash.sh` su un
Simulator creato appositamente, non autenticato e rimosso dal suo cleanup.
L'harness non ha effettuato chiamate di rete e non ha toccato Simulator o
database autenticati.

| Scenario | SIGKILL | Relaunch verificato | Generation attiva |
| --- | --- | --- | --- |
| Prima del rename del manifest | eseguito | verde | G-old coerente |
| Dopo il rename del manifest | eseguito | verde | G-new coerente |

Risultato: `executed=2`, `passed=2`, `failed=0`, `skipped=0`,
`authenticatedSimulatorTouched=false`, `networkCalls=0`.

## Gate eseguiti

I gruppi mirati si sovrappongono alla full suite e non vanno sommati.

| Gate | Risultato reale |
| --- | --- |
| V6 recovery/atomic/tail storico | `91` pass, `0` failure |
| Contratto migration V6 corretto, mirato esatto | `41` eseguiti, `41` pass, `0` failure |
| UI e copy release | `26` pass, `0` failure |
| Classi che fallivano nello storico precedente | `62` eseguiti, `0` failure, `1` skip camera fisica |
| ProductImageAPIClientTests | `25` eseguiti, `0` failure, `3` skip opt-in |
| Fixture sync-event V6 coinvolte | `177` pass, `0` failure |
| XCTest full finale, sorgente esatto post-allineamento | `1.261` eseguiti: `1.226` pass, `0` failure, `35` skip, `0` expected failure; durata XCTest `209,629 s` |
| build-for-testing Debug | `PASS`; un warning tooling AppIntents senza dipendenza AppIntents, nessun warning Swift della patch |
| `xcodebuild analyze` | exit `0`; `18` warning soltanto in `Vendor 2/libxls` (`17` `xls.c`, `1` `ole.c`), nessuna diagnosi nei file iOS modificati |
| Swift parse V6 + fixture interessate | `18` file, `PASS` |
| `plutil -lint` | Info/config + quattro Localizable, `6/6 PASS` |
| workflow YAML | `1/1 PASS` |
| scan locale redatto di credenziali/URL firmati | nessun literal `service_role`, `sb_secret` o JWT rilevato; URL firmati presenti solo come valori runtime bounded, non loggati |
| Codex Security diff scan formale | `NOT_RUN`: workspace già aperto ma non avviato nell'interfaccia; il controllo locale non lo sostituisce |
| `mc-agent scan evidence` sul worktree isolato | `NOT_VALID/MISCONFIGURED`: `mc_load_config` ricarica `config.example.env` e sovrascrive `MC_IOS_REPO`; non è una prova del worktree isolato |
| `git diff --check` e staged diff check | `PASS`, staged `0` |

Xcresult full finale: artifact esterno del run, non versionato.

Il run precedente da `1.253` eseguiti, `1.218` pass, `0` failure e `35` skip
resta storico ma è superseduto: è anteriore alla correzione P1 del contratto
digest.

Storico failure, da non cancellare:
xcresult esterno con `1.160` pass, `58` failure fixture pre-V6 e `35` skip.

## Skip espliciti della full suite

`xcresulttool` riporta `35` **Test Case** skip (i quattro nodi aggiuntivi
sono suite aggregate). Ogni skip ha il messaggio XCTest qui sotto; non è stato
abilitato un gate live/staging, una mutazione locale o un device fisico non
autorizzato solo per ridurre il conteggio degli skip.

- `13`: `TASK103_LIVE_ACCEPTANCE`, `TASK104_PASS2_LIVE_ACCEPTANCE`,
  `TASK112_LIVE_ACCEPTANCE`, `TASK114_LIVE_ACCEPTANCE` o
  `TASK072C_LIVE_ACCEPTANCE` non impostati. Casi:
  `Task103CrossPlatformAcceptanceTests.test01PreflightAndCollisionScanReadOnly`,
  `test02IOSWriteSmokeAndRemoteReadBack`, `test03IOSPullApplyAndroidSmokeAndNoOp`,
  `test04MediumImportExportPushAndReadBack`,
  `test05ConflictStaleRecoveryAndProductPriceFailClosed`,
  `test06OfflineRetryCatalogPendingNoDuplicate`,
  `test072CIOSCreateUpdateTombstoneHistoryHarness`,
  `test07Task104Pass2ResidueScanReadOnly`, `test08Task112ScopedCleanupWhenEnabled`,
  `test114IOSOfflineReconnectProductPriceHistoryMatrix`,
  `test114IOSPullAndroidProductHistoryMatrix`,
  `test114IOSWriteProductHistoryMatrix`, `test123IOSSingleCatalogCreatePropagation`.
- `4`: `TASK100_D100L` non impostato: i benchmark costosi
  `Task100LargeDatasetAcceptanceTests.testS100BDatasetManifestLargeWhenEnabled`,
  `testS100CImportExcelLargeDatasetLargeCoreBenchmarkWhenEnabled`,
  `testS100ESyncPreviewLargeSyntheticPagingBenchmarkWhenEnabled` e
  `testS100FProductPriceCurrentPreviousLargeBenchmarkWhenEnabled` non sono
  stati autorizzati.
- `4`: `TASK098_LIVE_SMOKE` non impostato:
  `Task098CrossPlatformSmokeTests.test01PreflightAndCollisionScanReadOnly`,
  `test02PullApplyAndroidProductAAndLocalReadBack`,
  `test03IOSWriteProductBUsingReleaseServices` e `test04RemoteReadBackB`
  richiedono il live smoke nel loro ordine documentato.
- `3`: `TASK100_LIVE_SUPABASE` non impostato:
  `Task100LargeDatasetAcceptanceTests.testS100ILiveSupabaseLargeWritePreviewAndCleanupWhenEnabled`,
  `testS100JLiveSupabaseCleanupPrefixWhenEnabled` e
  `testS100KLiveSupabaseReadOnlyVerificationForExistingPrefixWhenEnabled`
  richiedono la write/sync acceptance live.
- `2`: `TASK108_EXCEL_PATH` non configurato: `testTask108RealExcelCleanSeedImportCountsWhenEnabled`
  e `testTask108RealExcelProductPricePagedFullPullNoopWhenEnabled` richiedono
  l'harness Excel reale.
- `2`: `TASK072D_LIVE_ACCEPTANCE` non impostato:
  `Task072DLiveAcceptanceHarnessTests.testTask072DExportSessionForAndroidImport`
  e `testTask072DIOSCreateUpdateTombstoneHistoryHarness` sono live acceptance.
- `1`: `SupabaseConfigSecurityTests.testTask103IOSAuthPreflightWhenEnabled`:
  auth preflight live gated.
- `1`: `Task103CrossPlatformAcceptanceTests.test114IOSFullPullMaterializesRemoteLookupOnlyRowsInAppStore`:
  `TASK114_IOS_FULL_PULL` non impostato.
- `1`: `Task097RuntimeSmokeTests.testTask097RuntimeSandboxReadBackEvidence`:
  `TASK097_RUNTIME_SMOKE` non impostato.
- `1`: `ProductImageAPIClientTests.testOptInLocalParityNoImageAndProgressiveProductImage`:
  `TASK138_LOCAL_PARITY_CONFIG_PATH` privacy-safe non impostato.
- `1`: `ProductImageAPIClientTests.testOptInLocalParityMutationRemovesProductImage`:
  `TASK138_LOCAL_PARITY_MUTATION_MODE=remove` non autorizzato.
- `1`: `ProductImageAPIClientTests.testOptInLocalParityMutationReplacesProductImage`:
  `TASK138_LOCAL_PARITY_MUTATION_MODE=replace` non autorizzato.
- `1`: `Task105RealOpsClosureTests.testPhysicalCameraBarcodeCaptureCapabilityWhenAvailable`:
  la capability ha senso solo su iPhone fisico.

Il wrapper evidence non è stato rilanciato dopo la diagnosi: due tentativi
precedenti hanno scritto ciascuno la propria terna `md/json/log` nel checkout
Desktop originale già dirty, non nel worktree isolato. A parte quei sei
artifact, non sono stati toccati sorgenti, configurazione, test, Simulator o
dati applicativi di quel checkout; gli artifact esterni sono lasciati intatti e
non vengono usati come evidence di questa lane.

## Review e limiti

- `P0`: nessuno trovato nella review locale del contratto e dei boundary
  owner/shop/device; non equivale a una review formale cross-repository.
- `P1` locale: il mismatch del contratto digest e quello fisico cross-domain
  sono corretti e coperti rispettivamente da `41/41` + full suite esatta e da
  staging separato, mutation fence, manifest fsync/rename e SIGKILL/relaunch.
- `P2`: durante la full suite il test di scroll `ProductImageAPIClient` ha
  emesso una diagnostica SwiftData `DefaultStore` su un temporary identifier;
  il test e la suite sono passati e le riesecuzioni isolate precedenti non
  l'hanno riprodotta. Resta osservazione da riprodurre prima di classificarla
  come difetto runtime.
- Limite esterno: marker/RPC sono esercitati contro fake locali; manca ancora
  la dimostrazione server↔client su backend/staging autorizzato. La security
  diff scan formale non è stata avviata.
- Blocco di accettazione TASK-139: manca il solo replace E2E autorizzato e il
  confronto forte cloud/local (digest, immagini, outbox e tre relaunch) sullo
  shop non-production. Non viene dichiarato PASS globale o `DONE`.

Non sono stati eseguiti commit, stage, push, merge, rebase, reset, clean,
deploy, modifica production, accesso a Simulator autenticato o rimozione di un
Simulator preesistente.

## Appendice autorevole — continuation pre-bound resource 2026-07-23

Questa appendice supersede soltanto i conteggi e i gate iOS indicati qui; non
trasforma TASK-139 in PASS globale o `DONE`.

### Test runtime del resource owner

`ProductImageOwnerStoreRaceTests.
testPreboundResource64LateCompletionsNeverPublishAnd100ConsumersSingleFlight`
esercita gli oggetti production `ProductImageService`, `ProductImageStore`,
`ProductImageCache` e l'autorizzazione owner/store:

- `64` reference A/G1 distinte sono arrivate fino al GET;
- le callback non cooperative sono state consegnate tutte dopo l'attivazione
  B/G2 e la disattivazione/purge A;
- tutte le load A sono fallite chiuse, UI A `nil`, disk entry stale `0`;
- `100` consumer B concorrenti same-key hanno ricevuto lo stesso JPEG;
- delta B: una sola read batch, un solo GET, una sola disk entry;
- la UI ha pubblicato B e non ha ripubblicato A.

Risultato mirato finale: `1/1`, `0` failure, durata `0,72 s`.
Xcresult esterno del run, non versionato.

### Relaunch di processo con risorse preesistenti

`tools/agent/task139_prebound_resource_runtime.sh` ha creato e poi eliminato un
Simulator iPhone 17/iOS 26.5 non autenticato. Il primo processo ha scritto,
tramite gli store production, cache immagine A, watermark A `41`, recovery
fence A e pending marker. Dopo terminate e nuovo launch:

- PID `46201 → 46219`, quindi processo realmente rilanciato;
- gate automatico B: `bindingMismatch`;
- gate Product Image B: negato;
- cache A leggibile, cache B vuota;
- watermark `A=41`, `B=0`;
- fence A leggibile, fence B assente;
- pending marker A leggibile;
- marker di stale publication assenti;
- rete `0`, Simulator autenticati toccati `false`.

Risultato: `executed=2`, `passed=2`, `failed=0`, `skipped=0`.
JSON conservato nell'evidence esterna del closeout.

Il crash harness atomico è stato riconfermato sullo stesso sorgente finale:
pre-manifest seleziona G1/`verified`, post-manifest seleziona
G2/`activated`, `2/2`, rete `0`. JSON conservato nell'evidence esterna del
closeout.

### Gate finali e artifact

| Gate | Risultato finale |
| --- | --- |
| Full XCTest iPhone 17 / iOS 26.5 | `1.262` totali, `1.227` pass, `35` skip, `0` failure, `0` expected failure |
| Durata XCTest | `211,328 s` (`211,667 s` suite wall) |
| `build-for-testing` finale | `PASS` |
| Debug build finale | exit `0` |
| Analyze finale | exit `0` |
| Info/config plist | `2/2 PASS` |
| `git diff --check` | `PASS` |

Xcresult full e summary strutturato: artifact esterni del closeout,
intenzionalmente non versionati.

Le `35` skip sono gli stessi gate opt-in/live/device già classificati nella
sezione precedente. Durante la full suite è riapparsa la diagnostica SwiftData
temporary identifier nel test scroll, che ha comunque passato; resta P2 da
riprodurre. Sono inoltre apparse diagnostiche SQLite in un test rollback
file-backed già esistente, anch'esso passato; non sono convertite in failure né
ignorate come evidence di produzione.

Storico trasparente: un primo boot effimero ha fallito con `launchd_sim` e ha
richiesto un retry; la prima compilazione del test ha trovato quattro errori
`await`/autoclosure; le prime esecuzioni hanno rivelato fixture
`httpBodyStream`, signed path e retention della callback non cooperativa
incomplete. Xcode ha ripetuto un errore infrastrutturale generico dopo
firma/validazione; il `build-for-testing` definitivo successivo ha restituito
`TEST BUILD SUCCEEDED`. Nessun risultato intermedio è dichiarato PASS.

Questa evidence fornisce il runtime proof iOS per
`sec-mobile-prebound-resource-003`. La closure della security review globale,
l'E2E cross-platform non-production e Win7POS restano gate separati. La lane
rimane `REVIEW`; nessun commit, stage, push, merge, deploy o mutazione live.

### Certificazione immagini iOS

Le sei capture iPhone `1206x2622` già prodotte dal visual harness sono state
riaperte e ispezionate visivamente sul candidato finale. Lista, main ready,
thumbnail-progressive, editor, fallback errore e offline cache risultano
leggibili, senza overlap o clipping orizzontale. La capture thumbnail mantiene
intenzionalmente la riga di caricamento sul bordo inferiore del viewport; lo
stato essenziale è visibile e il test di pinning viewport è verde nella full
suite. Non è stata inventata una nuova cattura perché questa continuation non
modifica `ProductImageViews` o il visual harness.

Verdict immagini: `6/6 PASS_WITH_NOTE`. Copie hashate e manifest:
evidence esterna del closeout.
