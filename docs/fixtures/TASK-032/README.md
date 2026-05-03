# TASK-032 fixture

Fixture minima per validare `GeneratedView` / `RowDetailSheetView`.

## File

- `generatedview-task032-import.html`: sorgente HTML importabile dal flusso Inventario. Copre le 6 righe richieste dal planning con header canonici o alias riconosciuti.
- `generatedview-task032-history-entry.json`: snapshot interna equivalente a una `HistoryEntry` non manuale, con `data`, `editable` e `complete` gia' compilati per validare dettaglio riga, prev/next, CTA, badge e filtro errori.

## Note operative

- La snapshot JSON usa `editable[row][0]` come contata e `editable[row][1]` come vendita nuova, coerente con `GeneratedView`.
- Per D1/D2 sono marcate con `SyncError` le righe R2 e R5; il filtro errori deve quindi produrre un sottoinsieme di 2 righe.
- R6 usa `quantity = "abc"` come caso non numerico.
- Il file HTML serve per il flusso iOS reale di import/generazione. La colonna `SyncError` non viene prodotta dal normale import HTML: per validare D1/D2 serve una `HistoryEntry` gia' sincronizzata o la snapshot JSON caricata come stato interno.
