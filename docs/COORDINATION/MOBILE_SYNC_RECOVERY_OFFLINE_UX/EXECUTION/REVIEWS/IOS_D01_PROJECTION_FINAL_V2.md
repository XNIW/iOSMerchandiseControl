# Review statica iOS D01 projection final v2 e first-success-time

UTC 2026-10-16T05:19:57Z. Reviewer `/root/red_fixture_review`, distinto dal writer e dal runner root; subreview mirata indipendente di `/root/red_fixture_review/transport_static/d01_fixture_static`. **APPROVED_LOCAL_DELTA_STATIC** per i due artifact immutabili sotto dichiarati. Nessun ulteriore rilievo concreto nel perimetro richiesto. Non è approvazione runtime o globale: dopo la decisione statica root ha applicato i due artifact verificando i cinque hash attesi e ha avviato la regressione completa delle cinque classi, ancora **PENDING** alla scrittura.

## Versioni e pin

- [Ownership/projection final v2](../20261015-01/ios-d01-projection-fix-final-proposal-v2.patch), SHA256 `29709452a9f7532ca48a3382bdc78b481a6e7c74e12838e0801217cea09f734f`; [input v2](../20261015-01/ios-d01-projection-fix-final-proposal-v2-input.json), SHA256 `243890c5c23b2dedb3da93dff32e1afe8e84ac7b0084e67e5e23bb0d556e6d9d`.
- [First-success-time](../20261015-01/ios-d01-first-success-time-fix-proposal.patch), SHA256 `8754d8a918e66aefd7e21853eb0db78c5b99b0c86c1fe9db95d73deadc548e42`; [input sul v2](../20261015-01/ios-d01-first-success-time-fix-proposal-v2-input.json), SHA256 `b81ec2a6884c4ec722e1fe97ce66050a74e16a429b953b1ed5e78630c0ce33fb`.

Il reviewer ha verificato **5/5 basi e 5/5 hash proposti MATCH**, ricostruendo il testo soltanto in memoria senza applicazione a file. La base Atomic comprende il wait repair già qualificato: `395cef81c231b0e92f6a132c179e6e2749606ee9649204aee501815dc309e519`. La ricostruzione combinata dei due artifact produce questi sorgenti finali:

| File | SHA256 atteso |
| --- | --- |
| `SyncStateStore.swift` | `1c4c6b028d3b6108fb6365599e83f9d81738ea154bbfee72c535f4800ba4f156` |
| `SyncOrchestrator.swift` | `32e95936e9cdf28196413c1fc22da7e5bef04f2dc20ad092e4351a003b7a5ea6` |

Prima del solo fix temporale, StateStore v2 è `a8de770eb1296df02b16b7d1fe0e70a7182ab357b75f7417032594e77bca3050`. Gli altri tre hash dei test sono dichiarati nell'input v2. La receipt root di applicazione conferma i cinque hash combinati; non sostituisce il run successivo.

## Risultato mirato

L'orchestrator installa l'ID locale di presentazione prima di creare il Task e prima del primo await della decisione. StateStore richiede uguaglianza esatta con l'ID attuale per decisione, fase, progresso e intera pubblicazione del risultato. Un caller senza ID o con l'ID di A non può notificare, modificare stato/defaults o completare la claim recovery di B. Il cleanup di una receipt respinta usa lo stesso ID e revisione; non deduce più la perdita di ownership dal fatto che la generazione originaria sia diventata non corrente dopo il commit legittimo di B.

I guard successivi a `objectWillChange` ricontrollano ownership e revisione per fase, progresso, risultato e cleanup. Il guard immediatamente precedente all'ingresso runtime ricontrolla sia l'ID foreground dell'orchestrator sia quello dello StateStore; anche il begin del budget conserva questo requisito. Il rilascio della presentazione è condizionato all'ID esatto e non abbandona il successore.

Il precedente artifact final `cbeda5f739859f8bf322fcb34720301520443d0b861f49b9d856258c0f52d425` aveva un residuo statico: la cancellation provvisoria preservava anche la revisione, consentendo a una fase precomputata prima del publisher di sovrascriverla. Il solo delta di produzione v1 → v2 sposta `activeProjectionRevision = UUID()` fuori dal ramo che azzera la claim. Ogni mutazione di `applyRunResult` invalida così il candidato precedente; la richiesta di cancel preserva comunque l'ID dell'operazione e non genera un nuovo envelope autorevole. Il cambio legittimo della generazione nella stessa entità non revoca, da solo, la claim del risultato held.

Hydration deriva status, outcome, blocco e completamento soltanto dall'envelope valido e corrente. Un record missing, foreign o corrotto non attribuisce l'errore precedente e non crea un nuovo latch dalla failure raw. Il journal reale prevale. Il solo `phase=recoveryRequired` esplicito senza typed key può restare intento conservativo legacy: non qualifica outcome, errore, data, proof o nuova authority e non rinnova il retry. I test legacy mantengono gli assert del latch e dei raw originali; i soli outcome dopo reopen senza provenienza diventano `nil`, con controllo dei bytes immutati. Il positivo network/block ora viene prodotto dall'engine con origine e tempo reali, conservando i precedenti assert sul blocco e sull'assenza di fase attiva.

La seconda esecuzione della fixture di cancellazione invoca un nuovo engine e il servizio Atomic sullo scope reale; non ripubblica il risultato della prima esecuzione. Gli assert qualificano una nuova generazione, finalizzazione, osservazione e invocation. Nomi, conteggi e assert del percorso retry originale restano attivi.

Il fix first-success-time richiede osservazione valida, coerente con il risultato e corrente, con generazione uguale alla finalizzazione verificata. Usa `observation.completedAt` originario per la prima prova, mantenendo il replay della stessa prova alla prima data. `verifiedConvergence`, finalizzazione originale e authority completa restano necessari. Il timestamp della consegna non viene più usato per inventare T0.

## Prove precedenti e limiti

Root ha archiviato canonical02: **1623 test, 1582 PASS, 5 FAIL, 36 SKIP**, con **19/19 UI PASS** e pin invariati. I cinque FAIL originali e gli artifact restano conservati: questa review non li sostituisce con il solo giudizio statico. Projection RED successivo: **4 metodi, 2 PASS, 2 FAIL, 0 SKIP**, con legacy/crash-window qualificati e il controllo B held all'ammissione già PASS. Il first-success-time è un RED distinto qualificato con tre assert, non una regressione attribuita per analogia.

Il nuovo controllo bootstrap B held dopo activation aveva inizialmente solo un difetto fixture: expectation `returnedB` attesa soltanto in teardown, verificata come unwaited alla fine del metodo. La [riparazione fixture](../20261015-01/ios-d01-held-bootstrap-wait-repair.patch), SHA256 `1e1e3a0a9749cf64834497eeb2084b37ff7a1ae88ccd805ee1e78ed141a9a940`, attende sul percorso normale e usa fallback senza doppia attesa; non modifica gli assert. Root ha qualificato il controllo riparato **1 PASS / 0 FAIL / 0 SKIP**, exit0, sulla produzione canonical02 originale. È una regressione protettiva attraversata fino alla pubblicazione finale legittima di B, non un product RED storico.

Il reviewer non ha eseguito SDK, build, test o device e non ha modificato sorgenti, test live o input congelati; ha scritto solo questo report. Il giudizio è limitato a ownership/projection, fixture dichiarate e fix T0 sopra identificati, senza nuovo audit. La regressione combinata delle cinque classi avviata da root deve ancora produrre il proprio esito. CI, canonical completo successivo, Release/analyze, installazioni, UI/live autenticata e accettazione globale restano gate distinti. **HOLD** dopo questo report: nessuna ulteriore analisi o modifica autonoma.
