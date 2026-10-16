# Android — confine di accettazione finale e handoff

Coordination key `MOBILE_SYNC_RECOVERY_OFFLINE_UX`, Android TASK-144. Redatto il **2026-10-16 05:18:24 UTC** dal reviewer `/root/android_r01_final_review`; seconda lettura documentale T01–T20 di `/root/android_r01_final_review/transport_check`. Repository candidato: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`, HEAD `4b74ed5cfb4e4bce024513561e7dc1b6998003ae` più modifiche locali. Questo rapporto collega gli esiti già archiviati ai criteri della [matrice canonica](../../TEST_MATRIX.md); non modifica matrice, task, sorgenti o installazioni e non introduce un nuovo audit.

**Gate locali PASS e review `APPROVED_LOCAL_DELTA`; accettazione delle app reali ancora BLOCKED dalle prove mancanti indicate sotto.** Nessun CA01–CA12 o T01–T20 completo viene dichiarato PASS per effetto della suite UNIT. Il repository conserva WIP e il candidato non è un commit finale certificato da CI.

## Evidenze utilizzate

| Riferimento | Evidenza archiviata | Cosa dimostra e limite |
|---|---|---|
| E01 | [Input finale](android-final-gates-01-input.json), UTC 2026-10-16T04:42:04.895972Z | Freeze di 20 file; Event source `199bc154cfcfdd8eb513c0a4f6e1277361839b42829db54470cb537f77539617`. Non è un hash dell'intero checkout né della configurazione delle app installate. |
| E02 | [Output finale](android-final-gates-01-output.json), UTC 2026-10-16T04:46:31.204246Z; [comando](android-final-gates-01-command.json), [log](android-final-gates-01.log) | Exit 0 e 20 pin invariati; risultati unit/build/lint sul freeze E01 e sulla toolchain locale preservata. Nessuna installazione o prova TEST contenuta in questo gate. |
| E03 | [Summary UNIT](android-final-gates-01-summary.json), UTC 2026-10-16T04:46:30.873220Z; [XML](android-final-gates-01-results/) | **1328 casi: 1321 PASS, 0 FAIL, 7 SKIP**. Le fixture deterministiche e gli eventuali loopback sono prove UNIT/host; non sono sessioni native autenticate o convergenza TEST fra app. |
| E04 | [Review finale indipendente](../REVIEWS/ANDROID_FINAL_LOCAL_REVIEW.md) | `APPROVED_LOCAL_DELTA` sul freeze20; root ha aggiunto separatamente gli esiti del runner. Include rimandi ai RED preservati, alle review precedenti e al finding schema blank corretto prima del gate finale. Non è approvazione globale di distribuzione. |
| E05 | [Preservazione APK/installazione](android-apk-evidence-preservation.json), UTC 2026-10-16T04:45:15.830599Z | APK storico fuori dalla directory Gradle conservato e corrispondente alla receipt originale; nessuna operazione device/install/reset in questa execution. Stato corrente del device non ricontrollato. |

Hash SHA256 delle fonti documentali lette: E01 `775ae28a10c77de74137a99a43854644e26a7c47b1027690ff5f0c2fbbc0448d`; E02 `ad18cf8bfd41c9991d34300624a8b5d446343e1356e6b54310f4f48071054fe1`; E03 `0550ef2ea26a8705b1fa7e45ead88a4c418cd8bd22174617084c908161133e01`; E04 con appendice runner `245fe072acc94cf63c206376d9fdc205ce232530914c7b90ff6fae35a7536e05`; E05 `4e4939dfb97e4f057afb75e299159023f18979abf9d85b9c10f9aa6f509f5eac`. Non sono stati ricalcolati gli hash degli APK né interrogati i device per questo rapporto: per quelli vale la receipt E05.

## Gate locali, toolchain e pacchetti

| Gate | Esito effettivo E02/E03 | Confine |
|---|---|---|
| `:app:testDebugUnitTest` | PASS, 1321 PASS / 0 FAIL / 7 SKIP | I sette casi sotto non sono stati attraversati. |
| `:app:assembleDebug` | PASS | APK Debug firmato per debug, archiviato, **non installato**. |
| `:app:assembleRelease` | `PASS_UNSIGNED_BUILD_ONLY` | APK Release **unsigned**, non distribuibile così com'è; nessuna prova di firma o upgrade. |
| `:app:lint` | `PASS_debug_report_release_vital_skipped` | Report Debug: 57 warning, 0 errori; nessun finding correlato alle linee aggiunte. Non è un confronto con baseline lint; Release vital risulta skipped e non viene dichiarato eseguito. |
| Warning compilazione | 0 warning Kotlin; 209 warning D8 da bytecode WeChat esterno | Log conservato; nessuna equivalenza quantitativa con una nuova baseline dex viene assunta. |
| CI sull'esatto SHA finale | **NOT_RUN** | Gate locali su working tree, distinti dalla CI canonica e dall'integrazione. |

Il run ha usato la toolchain **WIP preesistente preservata**: Gradle 9.6.0, AGP 9.4.1, KSP 2.3.6. La configurazione HEAD dichiarata in E02 è Gradle 9.5.1, AGP 9.2.1, KSP 2.3.4. Le modifiche WIP non sono state ripristinate né integrate; i gate non certificano automaticamente la configurazione HEAD o una futura revisione integrata. E02 dichiara invariato il contratto versioni Supabase/Ktor rispetto a quel WIP.

Gli [APK finali archiviati](android-final-gates-01-artifacts/) sono distinti dal binario storico:

| Pacchetto | SHA256 dichiarato da E02/E05 | Stato |
|---|---|---|
| `app-debug.apk` | `a1751d3506f1e595f066bb13e3aac3774bed29f16281e1751ac623b59896cb6a` | `DEBUG_SIGNED_NOT_INSTALLED`, 129050388 byte. |
| `app-release-unsigned.apk` | `a50492a9c49b1eb080e5c1b0484cee254cb9a1508b412d7de70d5e2fd8106ade` | `UNSIGNED_NOT_DEPLOYABLE`, 96061207 byte. |
| APK storico integrato TEST conservato | `1510010be33b2201343e2fcf97b188034b71f56eb95fb76813c74be8c8d8bb3e` | Receipt storica conservata; non sovrascritto da questa execution. L'installazione corrente è rimasta intatta per assenza di operazioni, ma il suo stato e la sua lineage corrente sono **UNKNOWN**, device recheck **NOT_RUN**. |

E05 contiene i percorsi assoluti del binario storico e della receipt originale. Non si attribuiscono al binario installato i nuovi sorgenti o i nuovi PASS: i nuovi APK non sono stati installati.

## Mappatura CA01–CA12

La colonna finale riguarda il criterio applicativo completo richiesto dalla matrice, non l'esito dei sottoassert UNIT. Le prove UNIT pertinenti sono specificate nella tabella T01–T20 successiva.

| CA | Supporto locale effettivo | Prova che manca | Esito del criterio completo |
|---|---|---|---|
| CA01 — lineage candidata/config/installazione | E01–E05: freeze20, output invariato, gate e APK nuovi archiviati, APK storico preservato. | Legame verificato fra una build installata, config/ambiente e dati attuali; upgrade T17; revisione integrata. | **UNKNOWN** per installazione/config attuale; solo sottoinsieme STATIC/BUILD eseguito. |
| CA02 — avvio/lettura/editor/Save offline | UNIT scope locale, mutazione atomica e rollback; T01/T02/T06/T14 parziali. | Cold start realmente offline, mount/ricerca/editor/Save e readback da app vera con scope ammesso. | **NOT_RUN** SIM/E. |
| CA03 — restart e ripresa automatica oltre budget | UNIT intent durevole, reopen, budget5, cooldown e singola opportunità futura; T03–T05. | Restart/reconnect delle app senza tap e ACK/readback peer. Stato delle righe legacy esaurite non qualificabili presenti realmente. | **NOT_RUN** runtime; legacy esauriti reali **UNKNOWN**. |
| CA04 — revoca/mismatch/corruzione e callback | UNIT lease, scope/epoch, vecchio ACK, revoca/ABA/cancel/device e deadline; T06/T07/T12. | Due scope TEST ammessi, logout/revoca/corruzione e osservazione dell'assenza di esposizione/mutazioni nell'app. | **NOT_RUN** SIM/E. |
| CA05 — merge e conflitto per record | UNIT editor disgiunto, overlap respinto e delete-vs-edit a review; T08/T09. | Merge bidirezionale effettivo, scelta conflitto e dato finale per ID/campi nelle app TEST. | **NOT_RUN** SIM/E. |
| CA06 — atomicità/replay/ACK/prezzi/history | UNIT rollback business+intent, envelope immutabile, Save B e accepted prefix/cutover; T03/T10/T13. | Fault pre/postcommit e riapertura nelle app vere, readback remoto/peer prezzi/history e unicità per ID. | **NOT_RUN** SIM/E. |
| CA07 — isolamento record e dipendenze | UNIT malformed head, keyset oltre una batch, lavoro indipendente e guard scope/business; T11. | Ledger per item nell'app e negativo supplier→product dipendente su fixture TEST, senza righe perse. | **NOT_RUN** SIM/E. |
| CA08 — recovery A–G riprendibile | UNIT checkpoint reale sintetico, staging/cursor persistiti dopo503, loading/refresh e attivazione AppREADY, cutover e reopen; T07/T12/T13/T14. | Tutti gli scenari A–G nella shell nativa, interruzioni/restart e verifica editor/pending per record. | **NOT_RUN** SIM/E; UNIT non certifica A–G completi. |
| CA09 — stato/date/count UX | UNIT outcome originario, holder qualificato, no restore dopo revoca/ABA, price partial e ricreazione VM; T15/T19. | Banner/card/date/count nelle schermate reali, incluso conteggio locale/cloud pertinente. La prova iOS localOnly è una lane separata. | **NOT_RUN** SIM/E. |
| CA10 — layout/input/lingue/accessibilità | UNIT di presentazione/localizzazione compresi nella suite, T14/T18 parziali. | Ultima riga, input/draft/focus/scroll, IT/EN/ES/ZH, font massimo, light/dark, AX e TalkBack/giudizio nativo. | **NOT_RUN** SIM/E e MANUAL/fisico. |
| CA11 — convergenza e prestazioni | UNIT applicazione catalogo/delta, idempotenza e relazioni; build locali; T16/T19 parziali. | Android↔iOS su TEST per ID/campi/versioni/tombstone/prezzi/history, 30 no-op, p50/p95/max nativi e soglie T20. | **NOT_RUN** runtime; benchmark grande è SKIP. |
| CA12 — gate/review/integrazione/finale | E02–E04: gate locali e review indipendente documentati. RED precedenti conservati nei rimandi della review. | CI exact-SHA, integrazione protetta, packaging/upgrade verificati e conferma applicativa finale. | **NOT_RUN** per gate successivi; nessun DONE globale. |

## Mappatura T01–T20 alle prove Android effettive

I nomi fra backtick sono selettori esatti presenti in E03. Tutti quelli indicati PASS hanno esito PASS nel run finale; il loro contenuto qualifica soltanto gli assert UNIT attraversati, non tutte le varianti dello scenario canonico. I link alle classi aprono gli XML finali. La seconda lettura documentale ha verificato i nomi e la distinzione UNIT/runtime.

| T | Evidenza locale già eseguita | Confine residuo applicativo |
|---|---|---|
| T01 | UNIT PASS, [ShopContextOfflineAuthorizationTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.ShopContextOfflineAuthorizationTest.xml): `143 ordinary reopen publishes durable selected scope before held network returns`. | Cold start rete assente, SDK Initializing/token cached, primo dato/frame e shell nativa: **NOT_RUN**. |
| T02 | UNIT PASS, [OperationalMutationIntegrityTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.OperationalMutationIntegrityTest.xml): `editor merge rolls back if dirty marker fails after product and price write`. | Editor/Save offline, dismiss, readback ID/campi/prezzo e ultima riga da UI vera: **NOT_RUN**. |
| T03 | UNIT PASS, [DefaultInventoryRepositoryTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest.xml): `catalogEventCancellationKeepsDurableIntentBeforeRpcAndExactReplayAfterReopen`; companion UnknownAck e replay business dopo reopen. | Restart non distruttivo dell'app prima invio/dopo commit ignoto e ripresa senza tap: **NOT_RUN**. Riapertura Room/JVM non equivale a riavvio app installata. |
| T04 | UNIT PASS, [ShopSyncRecoveryCoordinatorTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.ShopSyncRecoveryCoordinatorTest.xml): `recoveryCompletionResumesDurableCatalogIntentWithoutAnotherLocalSignal`. | Reconnect reale→admission→ACK→peer UI senza Opzioni/Retry: **NOT_RUN**. |
| T05 | UNIT PASS, stesso XML recovery: `automaticRecoverySchedulesOneFutureWindowAfterFiveTransientFailuresWithoutAnotherTrigger`; `automaticRecoveryStructured503PreservesAcceptedPricePageAndCursorAfterReopen`. UNIT PASS coda: `q01CanonicalOutboxHonorsServerRetryAfterFloorAndBlocksInvalidHeader`. | Fault/retry/429/DNS/pre-postcommit osservati nell'app: **NOT_RUN**. Righe legacy realmente esaurite prive di prova typed/canonical sufficiente: **UNKNOWN**; il fail-closed verificato non dimostra loro convergenza. |
| T06 | UNIT PASS, [SupabaseAuthLifecycleTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.SupabaseAuthLifecycleTest.xml): `late direct SDK refresh cannot overwrite a new login of the same account`; negativi scope/lease nelle suite. | Refresh/nil temporaneo/logout con sessione TEST valida e capacità locali visibili nell'app: **NOT_RUN**. |
| T07 | UNIT PASS, XML recovery: `automaticRecoveryRealShopChangeDuringCheckpointNeverReplaysOldScope`; WAIT revocation/cancel/device/deadline. | Cambio account/shop, revoca e corruzione effettivi in due scope TEST ammessi, UI/readback per ID: **NOT_RUN**. |
| T08 | UNIT PASS, XML mutazioni: `editor name edit preserves price and image updates after editor opened`. | Cambi disgiunti fra app, stessa base e supplier/category/prezzi con readback bidirezionale: **NOT_RUN**. |
| T09 | UNIT PASS, XML mutazioni: `editor overlapping edit rejects all writes and history`; [Task126ConflictReviewTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.Task126ConflictReviewTest.xml): `delete versus edit routes to review`. | Scelta conflitto reale nelle app, versioni/intent e dato finale, indipendenza degli altri record: **NOT_RUN**. |
| T10 | UNIT PASS, XML repository: `143 late catalog ACK preserves fields from a second actual Save`, replay lost business ACK stesso/diverso campo e immutable event envelope. | Commit ignoto/replay/Save B su app vere e prova remota/peer di unicità evento/prezzo/history: **NOT_RUN**. Il POST503 loopback qualificato resta host-only. |
| T11 | UNIT PASS, XML repository: `malformedCatalogEventHeadDoesNotBlockSeparatelyAcknowledgedCatalogEvent`; `q01CanonicalOutboxKeysetSkipsMoreThanOneBatchOfRealFutureAndBlockedHeads`. | Ledger per item runtime, variante dipendenza supplier→product e barriere integrity su fixture ammessa: **NOT_RUN**. |
| T12 | UNIT PASS, XML recovery: `143 reopen after second page timeout reuses durably accepted first page and cursor`; structured503, healthy activation e AppREADY dopo same-shop refresh. | Recovery A–G complete, interruzioni staging/publish/finalization e shell reale: **NOT_RUN**. |
| T13 | UNIT PASS, XML recovery: `143 edit during recovery survives atomic cutover and normal reopen`. | Editor nativo aperto con Save nome/prezzo/history a cavallo del cutover, readback peer e writer stale: **NOT_RUN**. |
| T14 | UNIT PASS, XML recovery: `143 same scope verified snapshot remains navigable while recovery transport is held`. | Navigation stack, focus, tastiera, selezione/draft/scroll e 10 minuti di editing con quiet gap: **NOT_RUN**. Il predicato di navigabilità JVM non prova hit testing o UX. |
| T15 | UNIT PASS, [CatalogSyncViewModelTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.viewmodel.CatalogSyncViewModelTest.xml): `recreatedViewModelKeepsOriginalOutcomeDateWithoutAnotherSync`; `scopeTransitionCannotClearNewScopeCompletionPublishedBySynchronousSubscriber`. | Banner/date/count nelle schermate reali e ciclo remount/tab: **NOT_RUN**. Lo scenario completo 6ACK+3sent+6localOnly richiede la propria prova pertinente; nessun PASS iOS trasferito ad Android. |
| T16 | UNIT PASS, XML repository: `wechat 003 admin events converge catalog lifecycle and reject a foreign shop row`. | Create/update/delete/ref/prezzi/history Android↔iOS tramite TEST effettivo, manifest e cleanup esatto: **NOT_RUN**. Fixture remote finte non sono convergenza backend. |
| T17 | UNIT PASS, [AppDatabaseMigrationTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.AppDatabaseMigrationTest.xml): `migration 7 chain to current schema preserves history_entry_remote_refs and existing data`; packaging E02/E05. | Upgrade sintetico Debug→Release e Release→Release con firma/config compatibili, pending/journal/draft/sessione e readback: **NOT_RUN**. Release unsigned non permette di assumere tale prova. |
| T18 | UNIT PASS, XML VM: `selectedAppLanguageReformatsCachedSyncDetailsWithoutAnotherOutcome`; suite presentazione/localizzazione comprese. | Quattro lingue, font massimo, light/dark, ultima riga, keyboard, AX/TalkBack e giudizio nativo/fisico: **NOT_RUN**. |
| T19 | UNIT PASS, XML repository: `021 second manual refresh after bootstrap is idempotent without duplicated catalog or prices`; date/recreation della VM. | 30 cicli no-op nelle app, diff DB e trace RPC per fixture, false date/pending/proof: **NOT_RUN**. |
| T20 | [MobileParityLargeDatasetBenchmarkTest](android-final-gates-01-results/TEST-com.example.merchandisecontrolsplitview.data.MobileParityLargeDatasetBenchmarkTest.xml): `measure real repository queries and local editor writes at large scale` è **SKIP**. | Dataset sintetico 20k/40k, profiling nativo, contesa/lock, 30 campioni per direzione e Save/no-work, p50/p95/max e target ≤3s/≤5s: **NOT_RUN**. Nessun numero host storico usato come accettazione performance. |

## Sette SKIP preservati

Questi sono gli esiti originali di E03 e dei rispettivi XML, non PASS e non nuovi run richiesti implicitamente da questo rapporto. Non sono state rimosse assumption o cambiate fixture per farli passare.

| Classe / caso | Causa registrata nell'XML |
|---|---|
| `DefaultInventoryRepositoryTest` / `wechat 004 real local Supabase fixture converges through production incremental apply` | `WECHAT_004_LOCAL_E2E_FIXTURE` richiesto, assente. |
| `SupabaseRealtimeSessionSubscriberLiveTest` / `live realtime insert is materialized into Room` | `SUPABASE_TEST_REMOTE_ID` mancante. |
| `MobileParityLargeDatasetBenchmarkTest` / `measure real repository queries and local editor writes at large scale` | Benchmark sintetico grande opt-in. |
| `ExcelRecognitionAuditOracleLoopTest` / `runOrchestratedOracleLoopAndroidFirst` | Solo task dedicato `:app:excelRecognitionOracleLoop`. |
| `ExcelRecognitionDriveBatchAuditTest` / `auditDriveSupplierCorpusReadOnly` | Solo task dedicato `:app:excelRecognitionDriveBatchAudit`. |
| `ExcelRecognitionOracleV2Test` / `validatePinmarkAndModalinaWithIndependentRawWorkbookOracle` | Solo task dedicato `:app:excelRecognitionOracleV2`. |
| `ShoppingHogarLocalDebugTest` / `dumpShoppingHogarCurrentMapping` | Fixture workbook locale opzionale assente. |

Il `release_vital_skipped` del gate lint è riportato separatamente: non è uno degli SKIP UNIT sopra.

## Prossima prova e responsabilità di handoff

La lane locale ha raggiunto **REVIEW** con evidenze ripetibili e APK conservati. L'accettazione applicativa resta **BLOCKED**: mancano build/config installate qualificate, fixture/sessioni TEST ammesse e osservazioni native. Responsabile del prossimo avanzamento è il coordinator root con l'owner della lane Emulator/TEST e l'operatore autorizzato per sessioni e prove manuali; questo rapporto non autorizza installazioni, firma, deploy o modifica dell'ambiente.

Il prossimo passo è qualificare una installazione **sintetica separata** con hash/config/ambiente, preservare pending/journal e verificare T17 prima dei casi che dipendono dall'upgrade; poi eseguire e registrare le prove native/offline/reopen e TEST bidirezionali della matrice, con scope/fixture autorizzati. Per T20 occorrono dataset isolato e CSV grezzi con le distribuzioni previste; per T18 un operatore deve registrare AX/TalkBack e giudizio nativo. La CI sull'esatto commit finale e la gestione della toolchain WIP restano una lane di integrazione distinta.

I legacy esauriti non qualificabili devono restare **UNKNOWN** fino a classificazione/readback ammessi delle righe reali e a una decisione esplicita sul relativo gate. I test di fail-closed, di budget residuo e di correzione V6 qualificata non autorizzano un reset generalizzato dei contatori né la dichiarazione che ogni coda installata sia già utilizzabile. L'installazione esistente è rimasta intatta; nessun suo runtime è stato ricertificato da questa execution.
