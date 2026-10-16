# iOS retry candidata1 — review indipendente

Reviewer `/root/red_fixture_review`, distinto dal writer. Sorgenti verificati contro [manifest congelato](../20261015-01/ios-retry-candidate1-input.json). **CHANGES_REQUIRED**, non approvata.

- P1 ownership completion: `SyncStateStore.recordRunResult` completa ogni v2 in_flight senza identity/claim/invocation. Un risultato ordinario o obsoleto può bloccare o rendere ritentabile un altro tentativo. Richieste regressioni ordinary-result durante A e callback A dopo B, con metadata B immutati.
- P1 overflow: Retry-After20000000000s è finito ma la conversione in UInt64 nanosecondi supera il limite. Attesa sicura a chunk con deadline conservata, cancellation e prova persistenza/reopen.
- P2 staging: `AtomicGenerationRecoverySnapshotPullService.isResumableTransportFailure` non riconosce la nuova failure tipizzata, causando quarantena anziché prefix-resume dopo pagina accettata. Richiesta regressione sul percorso adapter reale con timeout e reopen.
- Gate owner: l'orchestrator entra nel runtime prima del gate current-account; facade rifiuta poi activeAccountMismatch prima di engine/claim/RPC. Il FAIL del negativo dimostra ingresso runtime rispetto all'assert, **non invio foreign**. Mantenere gli assert e qualificare scope prima runtime/begin.

Aritmetica finestre3, floor300s, jitter e preservazione v1 staticamente coerenti, subordinati alle correzioni. Build/test candidate1 affidati a root, risultati nel registro; la review non esegue SDK o mutazioni.
