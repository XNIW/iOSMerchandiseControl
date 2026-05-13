# TASK-105 Evidence 02 - Excel Small/Large Import

## Dataset

| Dataset | Tipo | Dimensione | Stato |
|---------|------|------------|-------|
| Small import | Fixture privacy-safe TASK105_SMALL | 30 righe dati, include duplicato e barcode mancante | PASS |
| Large import | Fixture XLSX sintetica TASK105_LARGE | 5.000 prodotti | PASS |
| Apply SwiftData | Fixture sintetica TASK105_DB | 1.000 prodotti, 20 fornitori, 15 categorie, 2.000 prezzi | PASS |
| Dati reali operatore | Non forniti | N/A | NOT_RUN, coperto da fixture equivalente dichiarata |

## Risultati funzionali

| Scenario | Esito |
|----------|-------|
| Dedupe su barcode duplicato | PASS: ultima riga valida aggiorna lo stesso draft e somma stock. |
| Riga senza barcode | PASS: errore rilevato senza bloccare le righe valide. |
| Parsing prezzi IT/decimal | PASS: `10,50` e `10.50` normalizzati. |
| Export/import XLSX large | PASS: file generato, riaperto e analizzato. |
| Apply SwiftData batched | PASS: prodotti, supplier, categorie e ProductPrice creati in memory store. |

## Metriche

- Large import 5.000 righe: parse/analyze sotto soglia 60s nel test mirato.
- Small import 30 righe: sopra soglia minima pre-run e con recovery critica.
- Regression TASK-100 medium import: PASS.
- Nessun crash osservato nei test automatici.

## Stato

PASS_WITH_NOTES: dati reali non forniti; fixture realistiche privacy-safe usate come equivalente dichiarato.
