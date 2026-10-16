# MOBILE_SYNC_RECOVERY_OFFLINE_UX — handoff dei gate locali

UTC di preparazione: 2026-10-16T05:47:07.457598+00:00. **LOCAL_GATES_PASS / REVIEW — accettazione esterna BLOCKED.** Gate locali conclusi e verificati dal root;nessun DONE globale. Task originali: iOS TASK-145 e Android TASK-144; iOS TASK-144 precedente resta sospeso, senza chiusura della causa storica A.

## Obiettivo compreso

Completare i fix e le verifiche locali dell'assegnazione mobile, preservando WIP, configurazione, installazioni, dati, sessioni e coda. Distinguere source/test/build/review da CI, pacchetto dispositivo, installazione e accettazione TEST. Nessun DONE globale deriva dai soli gate locali.

## File controllati

Elenco esatto e hash dei 19 file iOS: [freeze finale](ios-final-local-input.json), [patch finale](ios-final-local.patch). Elenco esatto e hash dei 20 file Android: [freeze finale](android-final-gates-01-input.json), [patch](android-final-gates-01.patch). Le configurazioni WIP protette restano separate dai pin prodotto/test; [baseline](baseline.json) e [ricontrollo06](protected-state-check-06.json). Nessun branch/worktree/index/stash è stato spostato o riscritto.

## Piano minimo seguito

Riutilizzati piano, runner e owner dell'assegnazione. RED reali e originali FAIL preservati prima dei fix; setup failure distinti da difetti applicativi. Un solo runner SDK pesante alla volta. Nessuna migrazione, dipendenza, API pubblica o modifica del protocollo server introdotta. Revisione indipendente dei delta e delle fixture prima dei gate finali.

## Modifiche fatte

- iOS: budget automatico di tre tentativi reali per finestra, backoff/jitter e minimo Retry-After, ripresa transient qualificata; contatore cloud che esclude le ricevute terminali localOnly senza cancellarle. Provenienza completa di proof e osservazioni; date dal completamento originale dell'Engine, errore/outcome/time dallo stesso envelope corrente. Claim locale prework, controllo della pubblicazione e cleanup del solo proprietario, cancellazione UI provvisoria che non oscura un commit durevole già concluso. Mapping/capture corretti per eliminare i sette warning introdotti, senza cambiare i guard.
- Android: budget durevole di cinque invii reali per finestra, intento/body/ID conservati prima della RPC, completion CAS, replay idempotente bounded dell'esito incerto; malformed head isolato senza oltrepassare dipendenze/authority. Claim/timer del solo scope corrente; refresh nel budget trasporto residuo; richieste fisiche one-shot sulle sole RPC canoniche previste. Data e risultato derivano dalla flight originale, senza rinnovo al replay o attribuzione ad altro scope.
- Fixture iOS: prima finalization mai pubblicata e callback ritardata, successore B reale dopo activation con budget in_flight, raw legacy/corrupt e interruzione della persistenza, real run2 dopo cancellazione con attesa completion+pubblicazione e cleanup posseduto. [Attribuzione dei dieci FAIL](ios-d01-final-regression-01-failure-attribution.json) e [disposizione GREEN ordinata](ios-d01-final-regression-01-failure-attribution-green.json) mantengono gli originali. Non sono state ridotte le guardie su dati/proof/stato/authority per ottenere verde.

Il setup dei due test UI ACK e SavedDraft era già riconciliato su main314cf533. Nessuna nuova patch UI o nuovo miglioramento dell'app è attribuito a questa execution; i casi sono stati rieseguiti fino in fondo sul candidato corrente.

## Check eseguiti

| Lane / gate | Esito | Evidenza e limite |
|---|---|---|
| Android full Debug unit | PASS,1328 totali:1321 PASS/0 FAIL/7 SKIP | [summary](android-final-gates-01-summary.json), [output](android-final-gates-01-output.json);20 pin invariati. Gli skip restano non attraversati. |
| Android Debug / Release / lint | PASS / PASS_UNSIGNED_BUILD_ONLY / PASS con note | [gate finale](android-final-gates-01-output.json); Release unsigned,57lint warning/0errori,0Kotlin warning e209D8 da WeChat esterno. Toolchain WIP9.6/9.4.1/2.3.6 preservata, distinta da HEAD. Nessun finding sulle addedlines; non è confronto quantitativo con nuova baseline lint/dex. |
| iOS regressione cinque classi | PASS,271/0 FAIL/0 SKIP | [summary](ios-d01-final-regression-02-summary.json),[output](ios-d01-final-regression-02-output.json);19 pin invariati. Il successivo delta compiler è qualificato dai gate finali. |
| iOS Debug e Release simulator | PASS / PASS | [Debug](ios-final-debug-build-output.json),[Release](ios-final-release-build-output.json);0source compilerwarning,19 pin invariati. CODE_SIGNING_ALLOWED=NO, nessuna distribuzione dispositivo. |
| iOS Analyze | PASS_WITH_VENDOR_AND_UNCHANGED_TEST_NOTES | [receipt corretta](ios-final-analyze-output-03.json):18libxls e8warning su righe test già segnalate,0warning addedlines; non viene dichiarato zero warning globale. |
| iOS full canonical locale | PASS1629/1593PASS/0FAIL/36SKIP | [input](ios-canonical-03-input.json),[comando](ios-canonical-03-command.json),[log](ios-canonical-03.log);tutto lo schema unit/UI,nessun only/skip. Il gate locale non è una nuova CI remota. |
| ACK e SavedDraft sul freeze finale | PASS28.590s/60.520s | C03UI19/19PASS;quattro lingue/fontgrandePASS159.308s. [Output](ios-canonical-03-output.json),[lineage](ios-canonical-03-case-lineage.json):5FAILC02 oraPASS,36skipimmutati e1623IDoriginari conservati. |
| Review indipendente | APPROVED_LOCAL_DELTA_STATIC / APPROVED_LOCAL_DELTA | [iOS](../REVIEWS/IOS_FINAL_LOCAL_REVIEW.md),[fixture](../REVIEWS/IOS_D01_FIXTURE_ALIGNMENT_REVIEW.md),[compiler](../REVIEWS/IOS_D01_COMPILER_WARNING_DELTA_REVIEW.md),[Android](../REVIEWS/ANDROID_FINAL_LOCAL_REVIEW.md). Reviewer distinto,nessun suo SDK/acceptance inferito. |
| Nuove righe sensibili | PASS / PASS_WITH_SYNTHETIC_FIXTURE_NOTES | [iOS finale](ios-final-sensitive-added-lines-03.json),[Android](android-final-sensitive-added-lines.json);nessun valore sensibile emesso. Perimetro19/20pin,non certificazione di tutto il repository o degli archivi storici. |
| Pacchetti/evidenze preservati | PASS locale | [Release iOS simulator copiata e verificata](ios-final-release-artifact-receipt.json),[APK Android finali](android-final-gates-01-output.json),[APK storico1510010…](android-apk-evidence-preservation.json). Bundle iOS per iPhoneSimulator con verify signature exit1,non dispositivo; installazioni utente non toccate. |
| CI exact-SHA / installazione / TEST | NOT_RUN | Candidato ancora working tree; nessun commit/push/install/live write/deploy in questo incarico. |

## Rischi rimasti

Le matrici [iOS12CA/20T](ios-final-acceptance-boundary.md) e [Android12CA/20T](android-final-acceptance-boundary.md) distinguono ogni prova locale dal gate completo. Collaudo delle app candidate installate, bidirezionalità TEST visibile per ID/revisioni, offline/riconnessione, riapertura, upgrade non distruttivo, accessibilità fisica e prestazioni native30campioni20k/40k restano da qualificare. Nessun CA completo viene promosso PASS dalle sole unit/UI sintetiche.

Legacy exhausted senza categoria strutturata resta fail-closed: preservazione del dato non è prova della liveness della vera installazione dopo upgrade. La causa storica iOS A resta UNKNOWN; la correlazione temporale HTTP500/SQL57014 non è il join causale esatto del device. Recovery TEST e journal installati non sono stati finalizzati da questa execution. Produzione non modificata.

## Aggiornamenti file di tracking e passaggio successivo

Handoff locale completato dal root: task e master passano a REVIEW,statoBLOCKED per prove esterne mancanti. Planning/Review/storia degli altri owner preservati;masterpre-handoff archiviati prima dei soli aggiornamenti del task corrente. [Registro execution](../EXECUTION_LOG.md) conserva le decisioni e gli errori del collector, con receipt corrette separate.

Il mandato locale registrato nella [baseline](baseline.json) esclude commit/merge/push, nuovi branch/worktree, installazione/reset/logout, live write/migrazione/deploy. Perciò i gate successivi richiedono il responsabile di review/integrazione: validare il candidato e la configurazione WIP, pubblicare normalmente la revisione ammessa, CI sull'esatto SHA, pacchetto dispositivo firmato e upgrade preservando dati/sessioni/coda; poi prove utente e nuove modifiche TEST Android→iOS e iOS→Android con nuovi operation ID, lettura peer automatica e readback. Offline e riapertura sono prove indipendenti. Nessun refresh manuale, ripubblicazione di eventi confermati o reset può sostituire questi gate.


Finalizzazione root: 2026-10-16T06:04:12.418868+00:00. [Check finale07](protected-state-check-07.json): tutti i 39 pin prodotto/test e Git dei due repository invariati dopo il canonical; i quattro file di tracking corrispondono alle receipt dei soli aggiornamenti autorizzati. Link locali verificati e diff --check PASS in entrambi i repository. I master precedenti all'handoff restano archiviati; nessuna modifica alle sezioni storiche o ai dati delle app.
