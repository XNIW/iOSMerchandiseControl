# R-I04 — XLSX namespace import evidence

Il reader iOS ignorava nomi XML validi con prefisso e rifiutava il workbook condiviso come privo di fogli/colonna barcode. La correzione imposta `XMLParser.shouldProcessNamespaces = true` nei cinque parser esistenti: worksheet, shared strings, styles, workbook e relationships. Attributo `r:id`, controlli risorse e comportamento delle parti opzionali restano quelli già approvati.

Questa cartella è un pacchetto documentale bounded preparato il **2026-10-01** dalle evidenze persistenti del coordinatore. Non è una nuova esecuzione. Il codice R-I05 e la suite finale sono verificati separatamente.

| Prova storica | PASS | FAIL | SKIP | Fonte conservata |
|---|---:|---:|---:|---|
| Tre regressioni reali ZIP/XML prima patch | 1 | 2 | 0 | [red-summary.json](red-summary.json) |
| Task111 dopo patch | 31 | 0 | 0 | [green-summary.json](green-summary.json) |
| Suite adiacenti realmente eseguite | 29 | 0 | 0 | [adjacent-summary.json](adjacent-summary.json) |

Il comando verde aveva nominato anche due classi inesistenti: il risultato rappresenta solamente i **31** casi Task111. La distinta run adiacente esegue `ExcelAnalyzerHTMLParsingTests`, `CatalogTextIntegrationTests` e `Task141NumericInputTests`, **29** casi. Non sommare suite assenti o trasformare questi test in collaudo cloud. Due failure rosse riportano `invalidFormat` sul workbook prefissato; il caso Unicode/CLP già compatibile restava verde.

Le tre regressioni coprono i due XLSX condivisi con SHA fissato, named sheets/relationships con `r:id`, shared strings, formato di padding degli zeri, Unicode, quantità, prezzi CLP, metadata/footer e duplicati con ultima riga prevalente. L'harness Excel sospeso non è riattivato. [source-hashes.json](source-hashes.json) conserva gli hash dei due file Swift e delle due fixture; nella preparazione sono stati riverificati direttamente tutti e quattro, i CRC ZIP e il delta applicativo di esattamente cinque righe rispetto a `d217a751232af76c7260da3c3329f1087f7ab0bd`.

La diagnosi Foundation del foglio reale è in [namespace-diagnostic.jsonl](namespace-diagnostic.jsonl): XML valido, 8 righe e 64 celle; con namespace processing disattivato il delegate ne riconosce zero, attivandolo riconosce tutte le righe/celle. È una prova tecnica del parsing, distinta dalla selezione tramite Files.

La prova normale UI successiva sul bundle TEST firmato R-I04 è rappresentata dai risultati persistenti: [export-semantic-comparison.json](export-semantic-comparison.json) confronta nove campi canonici per cinque prodotti; [reimport-no-op-comparison.json](reimport-no-op-comparison.json) conserva hash identici di tutti i record business prima/dopo, identificatori e revisioni, 10 righe prezzi, 21 pending locali e outbox eventi zero. La preview no-op disabilita Apply; annullare la preview non scrive dati. Sono fixture isolate senza owner autenticato e non dimostrano sync bidirezionale o zero pending operativo.

[manifest.json](manifest.json) conserva provenienza e checksum originali, la review storica `APPROVED`, il subset della receipt firmata (binary SHA `dee6058bb6228e36907e48cc7fe0336362335ed087f19ba7b8dfaebd6d1520f9`) e i limiti. Le fonti sono `evidence/ios-ri04-import/` e `test-builds/ios/signed-ri04/receipt.json` nella radice persistente del coordinamento mobile, esterna al repository iOS. Gli ID device sono redatti; i nomi executor dei simulatori sono generalizzati. Nessun valore di configurazione, sessione, log raw, screenshot o inventario completo della receipt viene copiato.

I percorsi temporanei originali di log, xcresult, normal UI e bundle non esistono più al momento della preparazione. I risultati/hash riportati per quei raw sono **storici, non riverificati ora**. Restano disponibili i summary e confronti persistenti qui copiati, con checksum della fonte nel manifest; la verifica attuale del sorgente non ricrea la prova runtime mancante. Non si dichiara un nuovo PASS, una nuova review indipendente o il task DONE.
