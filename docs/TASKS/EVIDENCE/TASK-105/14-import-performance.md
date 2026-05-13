# TASK-105 Evidence 14 - Import Performance

## Soglie

| Soglia | Risultato |
|--------|-----------|
| Large import >= 5.000 righe | PASS: fixture 5.000 prodotti. |
| Parse/analyze <= 60s | PASS: test mirato sotto soglia. |
| Export+import <= 90s orientativo | PASS: test mirato sotto soglia. |
| Crash | PASS: nessun crash nei test. |
| Freeze apparente | PASS_WITH_NOTES: parsing pesante spostato off MainActor; misurazione UI runtime limitata a simulator smoke. |

## Fix performance

`ExcelSessionViewModel.load` e `appendRows` ora eseguono parsing Excel in task detached cancellabili e applicano il risultato sul MainActor. In review anche il calcolo metriche post-load/post-append e' stato spostato off MainActor dove impatta dataset grandi. Questo riduce il rischio di blocco UI senza cambiare l'API pubblica.

## Regression

- TASK-105 targeted simulator: PASS, incluso path reale `ExcelSessionViewModel.load`; test camera fisica skipped come atteso su simulator.
- TASK-105 targeted physical iPhone: 6/6 PASS.
- TASK-105 large import 5.000 righe: PASS.
- TASK-100 medium import benchmark: PASS.
- Task089 export benchmark selezionati: PASS.

## Stato

PASS.
