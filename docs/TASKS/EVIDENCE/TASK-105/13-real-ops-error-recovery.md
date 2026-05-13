# TASK-105 Evidence 13 - Real Ops Error Recovery

## Recovery validati

| Scenario | Stato | Evidenza |
|----------|-------|----------|
| Riga import invalida | PASS | Test small import rileva barcode mancante senza scartare righe valide. |
| Duplicato import | PASS | Warning duplicato e merge deterministico sullo stesso barcode. |
| Export filename invalido | PASS | Nome preferito con `/` e `:` produce file safe. |
| Scanner unavailable | PASS_AFTER_FIX | Fallback manuale porta al campo ricerca Database. |
| Camera fisica autorizzata/configurabile | PASS | XCTest su iPhone reale ha configurato camera input + metadata barcode output; owner/operator ha confermato live scan PASS. |
| File provider cancel | STATIC_PASS | Nessuna mutazione se non arriva URL valido. |
| Destination share non disponibile | STATIC_PASS | Export crea file locale prima della condivisione; share reale non eseguito. |
| Retry import dopo errore | STATIC_PASS | ViewModel mantiene stato e messaggi errore, flusso riavviabile. |

## Conferma owner/operatore finale

Owner/operator confirmation received, identity redacted, 2026-05-13:

- Barcode trovato/non trovato e fallback manuale: PASS.
- Import Files, export reale, apertura/reimport/integrita' file: PASS.
- Annulla/retry dove applicabile: PASS.
- Nessuna stop condition aperta.

## Stato

PASS.
