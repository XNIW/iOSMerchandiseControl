# TASK-036 Fixture

Fixture documentali per validare il parsing HTML avanzato in `ExcelAnalyzer`.

| Caso | File | Atteso |
| --- | --- | --- |
| Header con colspan/rowspan | `html-colspan-header.html` | Le righe header raggruppate (`colspan` + `rowspan`) non spostano l'header reale; header atteso: `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice`. |
| Rowspan su dati | `html-rowspan-data.html` | Le celle con `rowspan` vengono replicate nella griglia rettangolare e le colonne dati restano allineate. |
| Piu' tabelle | `html-multiple-tables.html` | Le tabelle decorative prima e dopo la tabella dati vengono ignorate; viene scelta solo la tabella dati con header canonici. |
| Righe titolo prima dell'header | `html-title-rows-before-header.html` | Lo scoring header trova la riga `barcode/product_name/purchase_price/quantity/retail_price`. |
| Negativo decorativo-only | `html-negative-decorative-table-only.html` | Contiene parole simili a header (`barcode`, `productName`, `purchasePrice`) ma nessuna riga dati compatibile: non deve essere trattata come tabella dati. |
| Nested table | `html-nested-table.html` | Una tabella annidata in una riga decorativa non deve aggiungere righe/colonne alla tabella dati principale. |
| Append multi-file A/B | `html-append-inventory-a.html`, `html-append-inventory-b.html` | Due export con header diversi ma stesso header normalizzato devono aggregarsi senza duplicare righe header. |
| HTML minimale senza header reale | `html-minimal-no-header.html` | Il parser documenta il fallback conservativo: genera colonne `colN`, mantiene i valori grezzi sulle colonne generate e non promuove i dati a header canonici tramite euristiche aggressive. |
| Realistic anonymized minimal repro | `html-realistic-anonymized-minimal.html` | Caso anonimizzato con alias/localizzazione IT e naming snake_case; verifica mapping e allineamento senza dati sensibili. |

TASK-036 ha introdotto queste fixture come documentali/manuali. TASK-037 le duplica intenzionalmente sotto `iOSMerchandiseControlTests/Fixtures/TASK-036/` per includerle nel bundle XCTest; se una fixture cambia qui, va mantenuta allineata anche nella copia del test target.
