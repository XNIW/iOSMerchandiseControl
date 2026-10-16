# Android D01 candidata5 — review indipendente locale

Reviewer `/root/android_r01_final_review`, distinto dai writer; seconda lettura indipendente di `/root/android_r01_final_review/transport_check` per gate PRICE e CAS D01. Documento registrato il 2026-10-16T04:28:38Z su delega del coordinator. Nessuna build, modifica prodotto, installazione o accesso device eseguito dal reviewer.

**APPROVED_LOCAL_DELTA** soltanto per la candidata congelata descritta dal [manifest dei 15 file](../20261015-01/android-d01-candidate5-input.json) e dalla [patch immutabile](../20261015-01/android-d01-candidate5.patch). Repository Android `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`, HEAD `4b74ed5cfb4e4bce024513561e7dc1b6998003ae`; il candidato comprende modifiche locali non integrate. Tutti i 15 pin sono stati confrontati durante la review e coincidevano; nessun drift rilevato nella finestra esaminata. Questo verdetto non si estende automaticamente alle modifiche successive.

## Evidenze e perimetro approvato

Il runner del coordinator ha eseguito 141 casi JVM selezionati, 141 PASS / 0 FAIL / 0 SKIP, exit 0; [summary](../20261015-01/android-d01-candidate5-summary.json), [receipt output](../20261015-01/android-d01-candidate5-output.json), XML originali archiviati nella directory `android-d01-candidate5-results`. La receipt delle 04:10:51Z conferma `sourcePinsMatch=true`. Queste sono prove locali del candidato dichiarato, non acceptance di app installate, CI finale, TEST o UI.

- Continuation Loading: contesto interno per singola invocazione recovery automatica con claim. L'invoker registra prima della richiesta il timeout effettivo del client e l'inizio monotono; l'attesa usa soltanto il residuo, con cancellazione e limite temporale. Nessuna attesa osservata dentro transazioni Room o `businessDataScopeMutex`.
- La continuation dell'Application verifica job posseduto, job in esecuzione, owner/shop, claim `in_flight` nel journal scoped e device corrente. Un unico flow combina auth, contesto shop e device Room. Al termine ricontrolla claim e guard cloud corrente: l'accesso locale confermato conserva l'invocazione ma non autorizza nuovi RPC o commit. Il percorso diretto senza callback conserva il comportamento precedente.
- L'attivazione sana dopo refresh same-shop viene ripubblicata dall'Application solo contro baseline, binding, journal eliminato, device e receipt pertinenti. Il test distingue la nuova generazione durevole da `READY` nell'Application.
- Prefix503: la nuova discriminazione preserva il prefisso accettato sotto errore HTTP transitorio strutturato. Il test qualificato distingue ledger120/proiezione25 e verifica cursor, riapertura e assenza di redownload del prefisso. Il vecchio fallimento120contro25 resta evidenza di setup NOT_TRAVERSED, non è stato reinterpretato come root cause prodotto.
- PRICE legacy senza parent originali: il gate conserva ogni campo e applica l'esclusione prima del limite del batch. Il normale retry usa gli ID persistiti; la correction V6 rimane un percorso distinto con le proprie prove.
- D01: timestamp prodotto nella flight originale, holder dell'ultimo esito qualificato separato dai diagnostici, verifica owner/shop/store/local-store/schema/protocol/storeEpoch, nessun rinnovo della data al replay. La correzione CAS ritira solo i holder precedenti e preserva la nuova completion B pubblicata durante l'emissione dello scope.

Nessun ulteriore difetto concreto rilevato nel delta esaminato. L'approvazione non afferma che ogni possibile interleaving sia stato attraversato.

## Esclusioni e regressione successiva

Gli 8 test aggiunti successivamente (4 negativi WAIT e 4 negativi Q01), i relativi hook e le successive riparazioni di regressione non fanno parte di questa approvazione. Richiedono review del loro esatto insieme di pin, anche se il runner ne ha riportato PASS.

La successiva regressione Debug completa [android-regression-01](../20261015-01/android-regression-01-summary.json) ha riportato 1327 casi: 1288 PASS / 32 FAIL / 7 SKIP. I 32 FAIL restano aperti come evidenza distinta e impediscono un GREEN complessivo; non vengono annullati dai 141 PASS precedenti. Classificazione read-only iniziale:

- 10 FAIL trace/readiness/auth assumono configurazione JVM vuota o target diverso da TEST; il BuildConfig effettivo aveva configurazione presente e corrispondeva al pin TEST. Sono assunzioni ambientali da qualificare con profilo sintetico esplicito, senza alterare configurazione reale o guard prodotto.
- 2 FAIL Application single-flight/reservation mancano delle nuove precondizioni auth/shop effettivamente ammesse; il solo tracker `sync_recovery_required` non concede admission.
- 17 FAIL repository: 11 si fermano nella stessa fixture che costruiva il vecchio formato esaurito ripetendo errori PayloadValidation stabili; 6 riguardano budget iniziale, scadenze, formato diagnostico e log. Vanno riparati conservando payload/ID e asserzioni comportamentali, senza riabilitare loop su errori stabili.
- 2 FAIL coordinator hanno evidenziato la riduzione della conservazione del prefisso per errori non-contract Unknown. Il fault di attivazione tardiva è una regressione da correggere preservando rollback e staging; il test intitolato checkpoint drift attraversa anche il rifiuto della fixture `fixture_event_page_not_configured` e non certifica da solo la causa protocollare nominale. Nessuna autorizzazione ad abbassare le asserzioni staging per ottenere PASS.
- 1 FAIL VM contiene un callback SDK lifecycle fuori main, coerente con l'inizializzazione SDK dovuta alla configurazione ambientale; root cause definitiva e riparazione della fixture restano da verificare.

La review finale dovrà includere le sorgenti e le fixture dopo questi interventi e il risultato completo sul loro esatto pin. Il replay HTTP fisico503 degli eventi resta NOT_RUN/rischio statico; la prova sul checkpoint recovery non lo chiude. Legacy effettivi preesistenti, build/lint finali, installazione/upgrade, runtime nativo e convergenza bidirezionale TEST restano gate separati. Nessun DONE globale, push, merge o deploy autorizzato da questo documento.
