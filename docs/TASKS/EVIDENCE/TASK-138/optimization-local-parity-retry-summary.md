# Optimization local parity retry - compact summary

Source: `optimization-local-parity-retry.xcresult`, letto con
`xcresulttool get test-results summary` prima della compattazione.

- result: `Failed`;
- total: `1`;
- passed: `0`;
- failed: `1`;
- skipped: `0`;
- test: `ProductImageAPIClientTests/
  testOptInLocalParityNoImageAndProgressiveProductImage()`;
- device: iPhone 16e Simulator, iOS 26.2, arm64;
- causa: Cocoa `260`, config non trovata nel vecchio Documents container dopo
  la reinstallazione/rotazione del test host;
- richieste Product Images: nessuna, il test e terminato leggendo la config;
- secret scan del bundle prima della compattazione: `PASS`, come documentato in
  `09-optimization-review.md`;
- token, URL firmate e contenuto config: omessi.

Il bundle completo da circa `55 MiB` e stato rimosso dall'evidence di repository
e conservato temporaneamente come
`/tmp/task138-optimization-local-parity-retry.xcresult`. Il riepilogo preserva
il risultato utile; il nuovo runbook usa invece `.xctestrun` e il `/tmp` stabile
del Simulator.
