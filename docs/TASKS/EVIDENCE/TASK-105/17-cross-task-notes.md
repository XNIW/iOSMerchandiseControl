# TASK-105 Evidence 17 - Cross-Task Notes

## TASK-104

- TASK-104 resta DONE / REVIEW PASS FINAL / PASS_WITH_NOTES.
- TASK-105 non riapre TASK-104.
- TASK104_PASS2 viene mantenuto in retention per reproducibility.
- Nessun cleanup remoto eseguito.

## Android

- Nota ByteBuddy/attach classificata come accepted note separata.
- Nessun build/test Android eseguito per TASK-105.
- Android non e' usato come fonte primaria ne' porting 1:1.

## Supabase

- Progetto test consultato read-only.
- RLS/policies verificate per tabelle inventory/shared/sync rilevanti.
- Advisor legacy/ops riletti nel final completion attempt e documentati in evidence 09.
- Advisor non introdotti da TASK-105: tabelle legacy senza policy, funzione `record_sync_event` SECURITY DEFINER callable da authenticated, leaked-password protection dashboard, FK inventory non indicizzate e unused indexes.
- Nessuna mutazione DB.

## Final completion attempt

- Device fisico iOS usato per build/install/launch e test TASK-105 6/6.
- Owner/operator confirmation received, identity redacted: live scan, Files/import, export/share equivalente, integrita' file e operator acceptance finale PASS.
- TASK-105 passa a DONE.

## Stato

PASS.
