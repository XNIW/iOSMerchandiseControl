# TASK-036 Fixture

Fixture documentali per validare il parsing HTML avanzato in `ExcelAnalyzer`.

| Caso | File | Atteso |
| --- | --- | --- |
| Header con colspan/rowspan | `html-colspan-header.html` | Le righe header raggruppate (`colspan` + `rowspan`) non spostano l'header reale; header atteso: `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice`. |
| Rowspan su dati | `html-rowspan-data.html` | Le celle con `rowspan` vengono replicate nella griglia rettangolare e le colonne dati restano allineate. |
| Piu' tabelle | `html-multiple-tables.html` | Le tabelle decorative prima e dopo la tabella dati vengono ignorate; viene scelta solo la tabella dati con header canonici. |
| Righe titolo prima dell'header | `html-title-rows-before-header.html` | Lo scoring header trova la riga `barcode/product_name/purchase_price/quantity/retail_price`. |
| Negativo decorativo-only | `html-negative-decorative-table-only.html` | Contiene parole simili a header (`barcode`, `productName`, `purchasePrice`) ma nessuna riga dati compatibile: non deve essere trattata come tabella dati. |

TASK-036 ha introdotto queste fixture come documentali/manuali. TASK-037 le duplica intenzionalmente sotto `iOSMerchandiseControlTests/Fixtures/TASK-036/` per includerle nel bundle XCTest; se una fixture cambia qui, va mantenuta allineata anche nella copia del test target.
