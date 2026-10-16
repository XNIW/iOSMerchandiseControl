# TASK-145 — Sync automatica, recovery non bloccante e UX offline iOS

## Informazioni generali

- Task ID: TASK-145
- File task: `docs/TASKS/TASK-145-mobile-sync-recovery-offline-ux-ios.md`
- Stato: **BLOCKED**
- Fase attuale: **REVIEW**
- Responsabile attuale: **COORDINATOR / REVIEWER-INTEGRATOR — review finale e lane CI/app/TEST**
- Data creazione / ultimo aggiornamento: 2026-10-15 / 2026-10-16T06:00:27.497056+00:00
- Ultimo agente: CODEX_MOBILE_EXECUTOR
- Coordination key: `MOBILE_SYNC_RECOVERY_OFFLINE_UX`
- Verdetto documentale: **PLANNING_COMPLETE / READY_FOR_EXECUTION**, non avvio execution né problema risolto.

## Mandato / override registrato

L'utente assegna esplicitamente Codex come planner/coordinatore, autorizza analisi e scrittura reale di task/master/handoff, vieta patch applicative in questa esecuzione e richiede executor e reviewer indipendenti. Questo override consente le sezioni Planning/Decisioni e il riallineamento minimo del tracking; AGENTS/CLAUDE e regole globali restano invariati. TASK-144 è sospeso **BLOCKED**, ultima fase FIX, senza chiusura o perdita delle evidenze. Nessun nuovo branch.

## Scopo

Rendere la sync capace di riprendere automaticamente dopo errori transitori e mantenere la normale operatività locale nello stesso scope autorizzato. Correggere stato/contatori/date/rumore UI preservando durabilità, exact ACK, isolamento e recovery atomica. Parità con Android per invarianti e risultati, con implementazioni native.

## Stato attuale verificato e dipendenze

HEAD/main/origin/main/GitHub `314cf5332d0b889331802a3f886c1910b9b377b0`, CI38429535889 SUCCESS preesistente. Binario installato e21efd… con receipt Release-equivalent della baseline, TEST configurato; non build odierna. Recovery journal same-scope/staging, budget3 con identità esatta: esaurimento persistente dimostrato. Le sei voci business sono acknowledged; il contatore6 include sei ricevute localOnly. Non cancellarle. HTTP500 persistito, correlazione storica57014 senza join causale esatto.

WIP Xcode/evidenze preservato. Precedenti fix Task144 integrati riusati, caso A e acceptance esterne non chiusi. Fonti e dati sanitizzati: [RCA](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/ROOT_CAUSE_ANALYSIS.md), [baseline](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/baseline.json).

Controparte: [Android TASK-144](/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-144-mobile-sync-recovery-offline-ux-android.md). Backend: [riferimento Supabase](/Users/minxiang/Desktop/MerchandiseControlSupabase/docs/mobile_sync_recovery_offline_ux_planning_reference.md), contratto effettivo in Admin migration, live schema non verificato oggi. La diagnosi backend non blocca regressioni locali e correzione contatore dopo assegnazione execution.

## Cosa cambia per l'utente / cosa non cambia

Retry senza tap, locale disponibile quando realmente autorizzato, Opzioni raggiungibili, informazioni di sync sobrie e corrette. Restano auth/RLS/revoche, protezioni store/manifest, formato dati e dipendenze esistenti. Nessuna nuova funzionalità business, reset, reinstallazione, migrazione, nuova API pubblica, dipendenza o secondo motore.

## Planning — Codex su override utente

Fonte canonica: [CONTRACT](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/CONTRACT.md). Finding dettagliati IOS-R01/R02, IOS-U02/U01/D01, IOS-L01/L02, IOS-Q01 in RCA, con gravità, causa/prova, file/simbolo e regressione. L01/Q01 sono condizionali al RED; non sono root cause runtime già dimostrate.

File/simboli candidati:

- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`: eligibility, deferred foreground, recovery source e presentazione.
- `Sync/Automatic/Presentation/SyncStateStore.swift`: budget e provenance; `SyncState.swift`, `SyncStatusPresenter.swift`: proiezione.
- `Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`: `OptionsPendingAttentionCounter.countAll` esclude proof locali dal pending cloud.
- `Sync/Automatic/Core/AutomaticSyncEngine.swift`, `AutomaticSyncRetryPolicy.swift`: errori strutturati/retry.
- `ContentView.swift`, `OptionsView.swift`, `SupabaseAuthViewModel.swift`, `Sync/Policy/Task126SyncPolicy.swift`: shell/capacità/auth/UI, solo rami provati.
- `Sync/Automatic/Catalog/CatalogPushService.swift`: isolamento per-item solo dopo prova dipendenze.
- Test mirati elencati in [piano batch](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/IMPLEMENTATION_PLAN.md), risorse IT/EN/ES/ZH pertinenti e `docs/SYNC_POLICY.md` per modifica esplicita dell'eccezione di progresso indipendente.

I path `Sync/...` sopra sono relativi a `iOSMerchandiseControl/`. Non sono una lista di modifiche automatiche; il batch deve limitarsi ai file necessari al RED. Layout main usa VStack banner+contenuto: non applicare la vecchia proposta safeAreaInset/padding a un codice diverso.

Fasi: 0 baseline/owner, 1 RED, 2 capacità locale/shell residua, 3 retry, 4 integrità/indipendenza, 5 presentazione, 6 runtime/prestazioni, 7 review/consolidamento. U02 può essere corretto dopo1 senza attendere backend; dettaglio, rischi e stop in IMPLEMENTATION_PLAN.

## Decisioni e alternative

| Decisione | Alternativa scartata / motivo |
|---|---|
| Budget per finestra con opportunità futura soltanto transient | Retry infinito, azzeramento journal/budget o sync manuale obbligatoria mascherano il problema |
| Capacità locale qualificata distinta da cloud | Guard sempre vere/owner dal solo binding violano isolamento |
| localOnly rimane prova locale, non pending | Cancellare ricevute rompe integrità e non risolve recovery |
| Same-scope recovery conserva overlay/revisioni | Full replacement indiscriminato perde lavoro concorrente |
| Unica fonte contratto, policy update esplicito nel batch | Copie iOS/Android/Supabase divergenti o eccezioni silenziose |

## Criteri di accettazione

Vincolanti [CA01–CA12 canonici](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/TEST_MATRIX.md); nessun CA applicativo soddisfatto dal solo planning.

| ID | Oggetto iOS | Tipo | Stato / evidenza richiesta |
|---|---|---|---|
| CA01 | Baseline/candidato/installazione/WIP | STATIC/BUILD | NOT_RUN candidato; baseline RCA eseguita |
| CA02 | Locale offline, navigazione e Save | UNIT/SIM | NOT_RUN T01/T02/T06/T14 |
| CA03 | Retry oltre budget/restart senza tap | UNIT/SIM | NOT_RUN T03–T05 |
| CA04 | Logout/revoca/scope/callback | UNIT/SIM | NOT_RUN T06/T07/T12 |
| CA05 | Merge/campi/tombstone | UNIT/SIM | NOT_RUN T08/T09 |
| CA06 | Atomicità, exact ACK, prezzi/history | UNIT/SIM | NOT_RUN T03/T10/T13/T16 |
| CA07 | Indipendenza e dipendenze | UNIT/SIM | NOT_RUN T11 |
| CA08 | Recovery A–G e cutover | UNIT/SIM | NOT_RUN T07/T12–T14 |
| CA09 | Pending/date/errori veritieri | UNIT/SIM | NOT_RUN T15/T19 |
| CA10 | Layout/lingue/accessibilità | SIM/MANUAL | NOT_RUN T14/T18 |
| CA11 | Cross-platform e performance | SIM/BUILD | NOT_RUN T16/T19/T20 |
| CA12 | Gate finali/review/integration | BUILD/STATIC/MANUAL | NOT_RUN, review futura indipendente |

## Matrice test e protocolli

T01–T20 definiti integralmente nella [matrice canonica](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/TEST_MATRIX.md), con precondizioni/fault/local/remote/UI/strumenti/prova per ogni riga. Registro iOS iniziale: **T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20 = NOT_RUN**, perché execution non iniziata. Applicare `docs/CODEX-EXECUTION-PROTOCOL.md`; SIM/MANUAL esplicitamente richiesti nella futura execution, nessun obbligo di usare script UI legacy. T20:30 campioni/direzione, p50/p95/max, p95≤3s foreground sano, dataset locale sintetico20k/40k+, dettagli e limiti nel protocollo.

## Rischi rimasti

Timeout backend non localizzato, auth transitoria vs logout da riprodurre, callback stale, timer duplicati, Save concorrente al cutover e isolamento dipendenze. Live schema, UI/accessibilità e prove fisiche restano separati. Non trasformare test green in causa storica A risolta. Ottimizzazioni soltanto dopo misura; lavoro fuori ambito è follow-up, bug introdotti nei CA vanno corretti qui.

## Check planning / aggiornamenti tracking

- ✅ ESEGUITO STATIC: GitHub/local/source, diagnosi aggregata, policy/contratto, CA e handoff; evidenza RCA/JSON.
- ✅ ESEGUITO: scrittura task/dossier/master; preservazione WIP e link verificati nella consegna documentale.
- ❌ NON ESEGUITO BUILD/analyze/warning: soli documenti, nessun compilabile modificato (N/A di fase secondo protocollo).
- ❌ NON ESEGUITO UNIT/SIM/MANUAL: matrice preparata, non execution; nessun PASS applicativo.

## Handoff post-planning → executor distinto

[Handoff completo](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION_HANDOFF.md). Prossima fase prevista EXECUTION **solo dopo assegnazione successiva**; stato corrente resta PLANNING. Primo passo: baseline fresca e RED contatore U02/retry R01, senza toccare installazione reale. Backend live richiede ammissione circoscritta. Reviewer successivo indipendente usa [checklist](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/REVIEW_CHECKLIST.md).

## Execution / Fix / Review / Chiusura

Execution locale conclusa, passaggio EXECUTION → REVIEW. Il task resta **BLOCKED per le prove applicative esterne mancanti**; nessun DONE. Canonical03 locale: 1.629 casi, 1.593 PASS, 0 FAIL e 36 SKIP. La parte unitaria comprende 1.610 casi (1.574 PASS, 36 SKIP); tutti i 19 test UI sono PASS. I 19 pin sono invariati e non sono stati usati only/skip-testing. Tutti i 1.623 ID di C02 sono conservati: i cinque FAIL sono ora PASS e i 36 skip sono identici. La regressione sulle cinque classi ha inoltre chiuso i dieci FAIL precedenti: 271 PASS, 0 FAIL, 0 SKIP, con review indipendente degli adeguamenti delle fixture.

ACK PASS in 28,590 s, Saved/UnsavedIntentAcrossCutover PASS in 60,520 s, quattro lingue/font grande PASS in 159,308 s. Il setup UI era già riconciliato su main314cf533; questa execution non introduce una nuova patch UI e non certifica l'app installata. Debug e Release per simulatore sono PASS, senza warning di compilazione nei sorgenti. Analyze è PASS_WITH_VENDOR_AND_UNCHANGED_TEST_NOTES: 18 warning libxls e 8 nei test immutati, nessuno sulle righe aggiunte. Il bundle Release per iPhoneSimulator è copiato e verificato per hash; non è un pacchetto per dispositivo. Review finale: APPROVED_LOCAL_DELTA_STATIC sul freeze esatto. Gli originali FAIL/RED restano preservati.

CI sull'esatto SHA, integrazione, pacchetto dispositivo firmato, upgrade con DB/sessioni/coda preservati e TEST bidirezionale/offline/reopen sono NOT_RUN. Il coordinator/reviewer-integrator deve assegnare la lane successiva; l'operatore autenticato deve completare le prove app/TEST/fisico. Il mandato locale esclude commit/push/installazione/reset/logout/live write/deploy. Lo storico iOS A e la liveness del legacy exhausted restano UNKNOWN; benchmark nativi con 30 campioni su 20k/40k e accessibilità fisica sono NOT_RUN. [Handoff finale](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/20261015-01/LOCAL_GATE_HANDOFF.md), [CA/T correnti](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/20261015-01/ios-final-acceptance-boundary.md).

### Execution — assegnazione successiva 2026-10-16T02:15:45.420438+00:00

Execution ricevuta dopo il planning da coordinator01a14272; executor distinto dal planner. Baseline/WIP e risultati nel [registro canonico](/Users/minxiang/Desktop/iOSMerchandiseControl/docs/COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/EXECUTION_LOG.md). Solo esperimenti sintetici e batch ammessi; review successiva indipendente. Nessuna modifica reale o distribuzione implicita.


### Handoff post-execution → REVIEW — 2026-10-16T06:01:45.021167+00:00

Il risultato locale è implementato e verificato sul [freeze di 19 file](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/20261015-01/ios-final-local-input.json). [Review finale](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/REVIEWS/IOS_FINAL_LOCAL_REVIEW.md), [output canonico](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/20261015-01/ios-canonical-03-output.json), [preservazione06](../COORDINATION/MOBILE_SYNC_RECOVERY_OFFLINE_UX/EXECUTION/20261015-01/protected-state-check-06.json). Planning, Decisioni e Review storiche sono invariati. Nessun merge, commit, push o installazione.

Prove assenti e passo di sblocco:

- CI sull'esatto SHA e configurazione integrata: owner reviewer/integrator; validare patch e WIP, poi assegnare la pubblicazione normale.
- Pacchetto firmato, upgrade e app reale: owner integratore/operatore; preservare dati, sessioni e coda, con receipt della provenienza del binario.
- TEST bidirezionale, offline/reopen, upgrade legacy, accessibilità fisica e prestazioni: owner della lane autenticata; usare fixture ammesse, ID/revisioni/readback e metriche.

Finché queste prove mancano, l'accettazione comune resta BLOCKED; causa A e legacy restano UNKNOWN. Nessuno sblocco generico del Mac richiesto e nessun vecchio diniego trattato come fatto attuale.


### Handoff integrazione Git — 2026-10-16 UTC

Il responsabile di integrazione riprende il mandato umano di consolidamento e il §8 del mandato mobile: commit/push normali, review e merge dopo gate verdi. Il limite no-commit/no-push della precedente execution locale resta riferito a quell’incarico; non viene rimosso dalla baseline originale. Stato prodotto ancora **BLOCKED / REVIEW**, nessun DONE o acceptance runtime.

Selezione: soli file prodotto/test del freeze finale, tracking pertinente e ricevute testuali esplicitamente selezionate. Configurazioni WIP preesistenti escluse e copiate in backup privato verificato; nessun loro valore o binario pubblicato. Le prove locali mantengono la propria configurazione WIP e non vengono attribuite per equivalenza al nuovo commit. La configurazione pubblicata resta quella già in HEAD.

Riuso del branch remoto di integrazione già esistente, senza creare branch/worktree; PR normale e CI sull’esatto SHA con configurazione HEAD prima del merge. Gate richiesti per la qualifica CI: Android assembleDebug/lint/full unit; iOS Debug/full unit e UI/Analyze/scan. Release con i pin HEAD, pacchetto dispositivo, installazione preservativa, legacy reale, TEST, prestazioni e causa storica iOS A restano gate distinti, non promossi da questa fase. Nessuna installazione, live write, logout/reset, migrazione, deploy, dipendenza o accesso persistente introdotto.

Il risultato conclusivo con SHA/PR/CI e prova di preservazione viene consegnato fuori dai repository prodotto nel dossier Ecosistema `evidence/mobile-sync-integration-20261016/`, senza aggiungere commit sul vecchio branch dopo il merge. I riferimenti raw/local-only delle evidenze sono dichiarati nell’indice di pubblicazione del dossier canonico.
