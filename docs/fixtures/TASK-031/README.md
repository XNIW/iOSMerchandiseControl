# TASK-031 Fixture

Fixture documentali per validare il riconoscimento deterministico degli header in `ExcelAnalyzer`.

| Caso | File | Header atteso |
| --- | --- | --- |
| A HTML canonico | `canonical-headers.html` | `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` |
| B XLSX canonico | `canonical-headers.xlsx` | `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` |
| C snake_case | `snake-case-headers.html` | `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` |
| D localizzato IT | `localized-it-headers.html` | `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` |
| E negativo senza header | `no-real-header.html` | colonne sorgente `col1`, `col2`, ...; eventuali colonne obbligatorie inserite vuote non valgono come riconoscimento |
| F append compatibile | `append-compatible-a.html` + `append-compatible-b.html` | stesso `normalizedHeader`: `productName`, `barcode`, `purchasePrice`, `quantity`, `retailPrice` |

Per A-D, "riconosciuto senza override" significa che il ruolo punta alla colonna reale del file e contiene almeno un valore dati non vuoto. Per E il comportamento atteso è lasciare le colonne reali come `colN` e affidarsi all'override manuale.
