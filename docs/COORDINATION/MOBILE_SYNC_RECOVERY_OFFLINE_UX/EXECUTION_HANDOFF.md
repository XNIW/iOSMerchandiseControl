# Handoff all'executor distinto

Verdetto: **PLANNING_COMPLETE / READY_FOR_EXECUTION documentale**. Assegnazione execution ancora da parte dell'utente. Non iniziare patch da questo documento senza la successiva assegnazione. Planner di questo dossier non sarà executor/reviewer del proprio lavoro applicativo.

## Baseline e lettura obbligatoria

1. Master e task correnti: iOS TASK-145 `ACTIVE/PLANNING`, Android TASK-144 `PLANNING` (unico task operativo). Supabase root MASTER_PLAN mantiene IDLE con rimando coordinato.
2. README, RCA, CONTRACT, IMPLEMENTATION_PLAN e TEST_MATRIX nello stesso dossier.
3. Codice effettivo, task precedenti iOS144/Android143 e addenda pertinenti; non ripetere fix integrati.

Baseline iOS314cf533 / Android4b74ed5c; `baseline.json` conserva WIP/worktree/stash/index. I due file Xcode iOS e due file Gradle Android dirty non appartengono alla task. Untracked TASK140F/tools/agent-runs preservati. Nessun branch creato, nessun commit/push di planning. Preflight fresco prima delle patch: remote main/ancestry, PR/CI, dirty/index/stash/worktree, writer/runner/lock e source equivalence; inventario nuovo non giustifica reset/clean/stash automatico.

## Ownership

- Coordinator documenti: unico writer di questo dossier e tracking cross-repo.
- Executor iOS: esclusivamente file iOS/test/risorse del batch ammesso.
- Executor Android: esclusivamente file Android/test/risorse del batch ammesso.
- Backend: owner Admin distinto, nessuna patch SQL pre-autorizzata; Supabase workspace storico non è deploy root attuale.
- Reviewer: agente indipendente da ciascun writer sul diff immutabile e sulle prove; non una rinomina del writer.

Lane source possono operare su file disgiunti dopo assegnazione; build/test pesanti, Simulator/Emulator e sessioni live sono serializzati per owner. In presenza di executor concorrente, sola lettura sull'area contesa e passaggio ownership esplicito prima delle patch; nessuna duplicazione di runner. Il planning non ha inviato messaggi ad altri chat owner né chiuso i loro gate.

## Primo intervento concreto

1. Regressione IOS-U02 su `OptionsPendingAttentionCounter`: 6ACK+3sent+6localOnly→0, poi vero pending→1. Patch minima del solo conteggio, proof intatte. È indipendente dal backend.
2. Regressioni IOS-R01 e AND-R01/Q01 con recovery/queue reali isolate oltre fine finestra e ritorno server sano; clock/transport controllati e nessun tap.
3. Tassonomia transient/stable e scheduling secondo CONTRACT; verificare vecchie aspettative test3/5 tentativi e modificarle esplicitamente al nuovo contratto, senza rimuovere i limiti.
4. Per cold auth e queue indipendente, prima il RED discriminante. Poi batch2/4; non ampliare i gate globali per inferenza.
5. UX/date e runtime/performance, quindi reviewer indipendente e FIX→REVIEW.

I file e simboli attesi sono in IMPLEMENTATION_PLAN. Nessun codice speculativo o nuova colonna è requisito implicito. Se un batch richiede diversa architettura/schema/API, fermare quel batch e aggiornare planning con motivo e prova prima di procedere.

## Comandi di riferimento, NON eseguiti nel planning

Rileggere workflow/script alla baseline candidata. iOS `.github/workflows/ios-product-images-ci.yml`, comando canonico test Xcode con destinazione isolata, firma disabilitata solo per suite sintetica; non usarlo per attestare packaging TEST installabile. Conservare build Debug, Release e Analyze come gate distinti. Esempio da completare con percorsi assoluti del runner:

```sh
xcodebuild -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl -configuration Debug \
  -destination 'platform=iOS Simulator,id=<ISOLATED_DEVICE_ID>' \
  -derivedDataPath '<ISOLATED_DERIVED_DATA>' \
  -resultBundlePath '<UNIQUE_RESULT_XCRESULT>' \
  CODE_SIGNING_ALLOWED=NO test
```

Per RED mirato usare `-only-testing:iOSMerchandiseControlTests/<existing class>/<case>` dopo aver letto setup e verificato storage/transport isolati. Successivamente gate canonici senza esclusioni arbitrarie. Non cambiare deployment target/SDK/deps per far passare test.

Android: verificare JBR/SDK e preservare toolchain WIP; suite selettiva esistente, poi baseline pertinente/full, assemble, lint e compile androidTest separati dalla loro esecuzione:

```sh
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
ANDROID_HOME='/Users/minxiang/Library/Android/sdk' \
./gradlew testDebugUnitTest \
  --tests '*MerchandiseControlApplicationTest' \
  --tests '*CatalogAutoSyncCoordinatorTest' \
  --tests '*HistorySessionPushCoordinatorTest' \
  --tests '*SyncErrorClassifierTest' \
  --tests '*DefaultInventoryRepositoryTest' \
  --tests '*ShopSyncRecoveryCoordinatorTest' \
  --tests '*CatalogSyncViewModelTest' --console=plain
```

`assembleDebug`, `lintDebug`, eventuali build Release e test device devono usare configurazione qualificata e lane dedicata. Nessun test che scrive dati reali è ammesso dal semplice nome della classe. `tools/sim_ui.sh` legacy non è prerequisito: usare strumenti nativi autorizzati e prova effettiva.

## Prerequisiti esterni circoscritti

| Operazione futura | Prerequisito mancante oggi | Indipendente che può proseguire dopo assignment |
|---|---|---|
| Patch applicative | Assegnazione execution all'agente distinto e owner per repo | Nessun automatic start; dossier pronto |
| Accettazione Android del candidato | Receipt source/config dell'APK1510010… o nuovo artifact qualificato su istanza isolata | UNIT/source regressions |
| Join causale timeout backend | Ambiente TEST/scoped reader ammesso, hash RPC/schema applicati, request correlation | Retry e UI isolati; nessuna SQL/deploy mutation |
| T08–T16 con scritture live | Scope sintetico esplicito, manifest fixture e cleanup, sessioni normali valide, owner runtime unico | Test deterministic storage/transport |
| Input/accessibility/fisico | Simulator/Emulator controllabili; operatore per consent/OS unlock/VO-TalkBack e hardware dove richiesto | Static/build/unit e documentazione |

Il planning attuale ha usato solo read-only locale e receipt backend preesistente: non ha provato oggi RLS live, membership, lock backend o schema applicato. Il project-ref TEST non basta per autorizzare una scrittura. Nessun apply TEST/production, RLS broadening, service-role client, reinstall/reset, retry manuale o cancellazione pending autorizzati implicitamente.

## Prove da restituire e stop

Per batch: file/simboli, diff e SHA immutabili, motivo, comando/exit, RED/GREEN/adjacent test IDs, warning nuovi confrontati con baseline, CA/T01–T20 per piattaforma con tipo/stato/evidenza, durata/risorsa owner e cleanup. Errori rete/SQL devono conservare prima causa e codici sanitizzati. Per runtime: source/config/binary hash, scope pseudonimizzato, identity/revision/ACK e readback per ID/campi/relazioni, UI ordinaria realmente usata.

Non tornare a una scansione completa a ogni blocco: proseguire dal primo esperimento discriminante registrato. Stop sul singolo esperimento se authority/fixture/lock/cancellation/readback non affidabili. Nessun falso PASS da mock, conteggio, screenshot o banner sparito. Se build fallisce prima app, annotare ambiente/NOT_TRAVERSED senza chiamarlo bug sync.

## Handoff → Review e consolidamento

Writer aggiorna Execution/Fix e Handoff del suo task; coordinator allinea master solo per cambio reale fase/stato. Reviewer usa REVIEW_CHECKLIST e prove sul codice finale. Un finding corretto torna a REVIEW; nessun DONE automatico. Integrazione su main con commit selettivi, review e required CI esatta, preservando WIP; niente branch in questo planning né force-push/bypass. Un vincolo reale di branch protection va dichiarato e seguito, non disattivato. Fine richiede CA obbligatori, review APPROVED e conferma utente/pipeline; i gate rimasti UNKNOWN/BLOCKED restano visibili.
