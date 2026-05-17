# TASK-111 — 03 Supabase Impact Map

Data: 2026-05-17

## OBSERVED

- Nessuna migration Supabase applicata.
- Nessuna query live Supabase eseguita.
- Nessun insert/update/delete remoto o locale Supabase eseguito.
- Client iOS non e' stato modificato per usare `service_role`.
- TASK-109 resta BLOCKED / SOSPESO; TASK-110 resta DONE.

## INFERRED

- Le modifiche iOS TASK-111 possono aumentare righe `ProductPrice` locali originate da import Excel (`IMPORT_PREV`, `IMPORT_EXCEL`).
- Le modifiche passano attraverso `LocalPendingChangeAccumulator` esistente in `DatabaseView.swift` / `ProductImportViewModel.swift`; quindi eventuale push cloud resta nel perimetro sync gia' governato da TASK-109/TASK-110, non riaperto qui.
- Supplier/category case-insensitive riduce il rischio di duplicati locali che poi diventerebbero conflitti/pending cloud.

## ASSUMED

- Se il reviewer richiede live Supabase, usare solo prefisso `TASK111_*`, owner/dev verificato e snapshot prima di delete ampi.

## NOT_RUN

- Read/write/delete Supabase: NOT_RUN, non necessario per chiudere execution locale a REVIEW.
- Migration safety gate: NOT_RUN, non emersa migration necessaria.
