# Review indipendente iOS D01 errori, candidata1

UTC 2026-10-16T04:51:04Z. Reviewer `/root/red_fixture_review`, distinto dal writer e dal runner root, con subreview read-only di `/root/red_fixture_review/transport_static`. **CHANGES_REQUIRED** per il P2 di hydration descritto sotto. La review è statica: il full canonical02 è **PENDING**, senza approvazione runtime, UI, installata o globale.

## Pin esatto esaminato

- [Canonical01 manifest](../20261015-01/ios-canonical-01-input.json), UTC `2026-10-16T04:46:54.510550+00:00`, SHA256 `a63ba555ce7d35a25e76d715feebaf2218c3ae437e859313d79da9c4cdad830b`; [patch](../20261015-01/ios-canonical-01.patch), SHA256 `790bf29a95d433bb6d48846855242e3c3e7c275494d780e1532f1269c0d93e52`.
- [Canonical02 manifest](../20261015-01/ios-canonical-02-input.json), UTC `2026-10-16T04:48:03.232957+00:00`, SHA256 `7e2973c5dac83e8e6e8ab62c4167eb80c7683eb533cd8c56166303e3e0b8aea4`; [patch](../20261015-01/ios-canonical-02.patch), SHA256 `9d1d2177f4c742166bcaba01b2086f18a09e6b7ed3d65ef9f280715e437dd3aa`.
- **19/19 SHA256 MATCH** verificati su entrambi i freeze. Canonical01 → canonical02 cambia soltanto l'accesso dell'extension `SyncBlockReason` in `SyncStateStore.swift`, da private a internal; mapping invariato. Pin StateStore02: `a41b3ac22ec9ff6526e65fa1f57c8c3b27f4761a008b79fc9d3d31b0d939d1e6`.

Rispetto alla precedente D01 candidata2, il perimetro comprende sette sorgenti per osservazione/normalizzazione: engine, risultato, state store, orchestrator, runtime facade, watermark store e diagnostics snapshot in Options. Cambiano inoltre i due test file Atomic e Task118. Gli altri dieci pin, incluso Task119, restano invariati. Il confronto non riapre la review precedente né certifica eventuali modifiche successive.

## [P2] Hydration usa ancora lo stato terminale raw senza l'envelope corrente

`SyncStateStore.swift:667–676` ricostruisce fase e `lastOutcome` da `phase`, `lastRunStatus`, `lastRunBlockReason` e `lastRunErrorCode` globali. Il getter `:78–88` elimina il terminale soltanto se la chiave `lastRunObservation.v1` **esiste** e la sua origine non è corrente. Quando l'envelope manca, una failure legacy di A rimane quindi `.failed` o `.blocked` con il relativo outcome dopo binding/selezione B e riapertura. Il caso non è puramente ipotetico nel codice: `Task118AutomaticDomainTests.swift:874–892` imposta soltanto questi raw e richiede ancora `.blocked(.networkUnavailable)` come stato corrente.

La contaminazione è visibile anche se il nuovo snapshot nasconde correttamente codice e data: `OptionsView.swift:1535–1539` sceglie il titolo failed/blocked da `syncState.lastOutcome`, e `:1657–1659` lo colora rosso. Inoltre la hydration non usa lo status dell'envelope nemmeno quando questo è valido: un envelope corrente noWork più vecchi raw failed produce ancora failed. Tale combinazione può essere qualificata come finestra di interruzione fra la persistenza dell'envelope in `acceptObservation` (`SyncStateStore.swift:443–452`) e il successivo `applyRunResult` (`:284–287`); non si dichiara che una simile interruzione sia già stata osservata su device.

Questo contraddice la decisione iOS D01 in [RETRY_METADATA_DECISIONS.md](../RETRY_METADATA_DECISIONS.md), sezione osservazione di errore: raw legacy solo storico, snapshot/hydrate con lo stesso validatore, outcome/origine/tempo in un solo envelope. Il P2 richiede RED qualificato prima di un fix; nessuna modifica produzione è proposta come già verificata.

Prova minima richiesta: partire da una failure A reale, mantenere i raw originali ma rimuovere soltanto l'envelope per rappresentare il legacy; cambiare binding e selezione a B e riaprire lo StateStore. Codice/data e stato/outcome terminali di A non devono diventare il fallimento corrente di B, mentre i bytes storici restano immutati. Affiancare envelope foreign/corrotto e un envelope corrente noWork con raw failed trattenuti per la finestra di interruzione. Conservare il positivo della failure scoped corrente, i gate di recovery e il comportamento dei lavori attivi; non indebolire gli assert dei callback stale o della proprietà del lavoro B. Il vecchio test raw-only va corretto soltanto dopo aver qualificato il RED e la semantica richiesta.

## Restante delta statico

L'origine foreground viene catturata prima del lavoro e conservata attraverso gli await; il TaskLocal originario non viene sostituito dal binding selezionato alla callback. Il timestamp finale dell'engine precede `singleFlight.finish()` e gli await di cancellazione. Il completamento dell'osservazione può derivare la generazione committed dalla finalizzazione originale trattenuta anche quando il pending impedisce la convergenza verificata; questo non crea una prova di successo. `acceptVerifiedProof` richiede separatamente `verifiedConvergence` e l'autorità completa corrente.

Il parser dell'envelope obbliga i sei campi keyed dell'identità e li confronta letteralmente con i valori decodificati; il parser proof v2 aggiunge lo stesso controllo raw, respingendo normalizzazione/default inferiti. `null`, tipi errati, scalar e campi mancanti non ottengono fallback dal decoder legacy. Quest'ultimo e l'uguaglianza globale restano invariati. Le letture non riparano bytes corrotti né creano controller o device ID.

`WatermarkStore.generationProvenance` distingue assenza da metadata presente ma invalida, usando record versionato/checksum e cursore corrispondente, senza scritture. Il risultato originario e la generazione corrente devono corrispondere. Il replay della stessa invocation conserva il primo envelope; un'altra invocation dello stesso origin richiede un completamento strettamente successivo. Snapshot, codice, data e blocco per `cloudEventsIncomplete` derivano dall'osservazione scoped e non dai raw storici. L'attribuzione diagnostica di un rifiuto non concede autorità per inviare o scrivere. Nei callsite di produzione con osservazione assente non è stato individuato un ulteriore bypass concreto dei fence dell'orchestrator.

I nuovi casi di origine/generazione/bootstrap/replay/tempo attraversano i percorsi reali esaminati; nessun indebolimento di assert originali individuato nel confronto statico. Questo giudizio non implica che siano già GREEN nel full canonical.

## Esecuzione e limiti

Canonical01: root ha comunicato compilazione fallita per due access error a `SyncBlockReason.diagnosticsName` da `SyncAutomaticRunResult.swift:175/204`; test **NOT_RUN**, artifact originale conservato e 19 pin invariati. Canonical02 applica soltanto la correzione di accesso sopra descritta ed è nel runner root con tutte le unit/UI del canonical scheme, senza only/skip. Alla scrittura di questo report l'esito finale rimane **PENDING**.

Root ha comunicato due failure interim di vecchi casi Atomic in cui il rifiuto dell'origine stale lascia la fase del lavoro proprietario in `pullingEvents`/`checking` anziché `recoveryRequired`. Sono informazioni provvisorie del runner, non un esito finale qualificato o un ulteriore finding approvato in questa review: occorre prima l'archiviazione dell'esecuzione e la distinzione fra cleanup di A e proprietà corrente di B. Gli assert originali vanno preservati.

Il reviewer non ha eseguito SDK, build, test o device e non ha modificato sorgenti, test o freeze. Ha scritto soltanto questo documento su delega del root. Il RED di hydration è ancora da qualificare; il run canonical corrente non sana il P2 per assenza del relativo oracle. CI della candidata, Release/analyze, installazione, UI/live autenticata, cross-platform, performance e accettazione globale restano prove separate. Nessun DONE o chiusura della causa storica iOS A è inferito.


## Appendice executor — esito canonical02 e qualificazione del rilievo

UTC 2026-10-16T05:14:46.350713+00:00. Appendice del root, separata dalla review statica originale sopra. Il canonical02 è concluso: 1623 casi, 1582 PASS, 5 FAIL unitari, 36 SKIP; UI 19/19 PASS. ACK immutable-response PASS 28.324s; Saved/UnsavedDraftAcrossCutover PASS 59.152s. Manifest19/19 invariato, artifact originali in `../20261015-01/ios-canonical-02*`. Non è CI nuova né accettazione installata/TEST.

Il successivo qualifier `ios-d01-projection-red*` ha eseguito quattro casi: due PASS, due FAIL con cinque assert pertinenti. Missing legacy A→B e corrupt typed, e current typed noWork con raw failed precedente, hanno qualificato il rilievo di hydration; raw bytes e journal B preservati. Il positivo current typed blocked è PASS. Il negativo B attivo è PASS ma non copre un budget B già persistito dopo activation. Il fix è ancora esterno, in revisione; CHANGES_REQUIRED originale non diventa approvazione.
