# TASK-105 Evidence 16 - CA Ledger

## Stato

DONE / OWNER_OPERATOR_ACCEPTED. Nessun CA orfano. Production no-notes non dichiarato separatamente come claim globale.

| CA | Stato | Tipo | Evidence | Note |
|----|-------|------|----------|------|
| CA-105-01 | PASS | DOC/MANUAL | 01 | Consenso utente per dati test/fixture documentato. |
| CA-105-02 | PASS_NOT_APPLICABLE | DOC/DB | 01/19 | Nessuna mutazione Supabase; backup remoto non richiesto. |
| CA-105-03 | PASS | DOC/DB | 01/19 | Rollback locale via git/temp; DB remoto read-only. |
| CA-105-04 | PASS | TEST | 02/23 | Small import fixture 30 righe con errori/duplicati PASS. |
| CA-105-05 | PASS | TEST | 02/14/23 | Large import 5.000 righe sotto soglia. |
| CA-105-06 | PASS | DEVICE/TEST/SIM/MANUAL | 04/15/23 | Camera capability PASS; owner/operator live scan, scanner flow, barcode found/not found e fallback manuale PASS. |
| CA-105-07 | PASS | MANUAL/STATIC/TEST | 05/13 | Files import PASS; iCloud/Share/destinazione equivalente PASS o N/A se non usata, confermato da owner/operatore. |
| CA-105-08 | PASS | MANUAL/DEVICE/TEST | 06/23 | Export integrity PASS; export reale destinazione negozio e apertura/reimport file confermati PASS da owner/operatore. |
| CA-105-09 | PASS | MANUAL/DOC | 03 | Accettazione operatore finale PASS, identity redacted. |
| CA-105-10 | PASS | DOC/DB | 07/17/19 | TASK104_PASS2 retention decisa; nessun cleanup. |
| CA-105-11 | PASS | DOC | 08/17 | ByteBuddy/attach classificato separato da iOS. |
| CA-105-12 | PASS_WITH_NOTES | STATIC/DB | 09 | TASK-105 scoped scan pulito; note Supabase legacy/ops. |
| CA-105-13 | PASS | DOC | 10 | Gate final closure verificato; TASK-105 DONE; production no-notes non dichiarato separatamente come claim globale. |
| CA-105-14 | PASS | DOC | TASK/MASTER | Tracking riallineato; TASK-104 chiuso. |
| CA-105-15 | PASS | DOC | 00/10/11 | Nessun claim anticipato. |
| CA-105-16 | PASS | BUILD | 12/23 | Release simulator build exit 0. |
| CA-105-17 | PASS_WITH_NOTES | BUILD | 12/23 | Nessun warning nuovo nei file toccati; warning legacy preesistenti in regression slice. |
| CA-105-18 | PASS | TEST | 23 | TASK-105 targeted simulator PASS e physical iPhone 6/6 PASS; regression selezionati PASS. |
| CA-105-19 | PASS | DB/STATIC | 19/23 | Schema/RLS/policy Supabase verificati read-only. |
| CA-105-20 | PASS | DB/DOC | 19 | Mutazioni classificate; nessuna mutazione Supabase eseguita. |
| CA-105-21 | PASS | STATIC/TEST | 14/22 | Import progress/loading/error presenti; parsing e metriche off MainActor. |
| CA-105-22 | PASS | TEST/STATIC | 13/23 | Invalid/duplicate/export recovery coperti; provider reale nota. |
| CA-105-23 | PASS_WITH_NOTES | TEST/SIM | 14/15/23 | Freeze risk mitigato; background/interrupt reale NOT_RUN. |
| CA-105-24 | PASS | STATIC/SIM/MANUAL | 15 | Tutte le schermate review; owner/operator conferma nessuna nota UX bloccante residua. |
| CA-105-25 | PASS | DOC/STATIC | 15 | UX-P0 0; UX-P1 corretto o chiuso. |
| CA-105-26 | PASS_WITH_NOTES | STATIC/SIM | 21 | Label/focus/target statici; VoiceOver completo NOT_RUN. |
| CA-105-27 | PASS | STATIC/SIM | 22 | Empty/loading/error/progress states verificati. |
| CA-105-28 | PASS | TEST | 06/23 | File export non vuoto e riapribile. |
| CA-105-29 | PASS | TEST | 14/23 | Large import entro fascia. |
| CA-105-30 | PASS | DOC | 00...23 | Evidence 00...23 compilate. |
| CA-105-31 | PASS | DOC | 18 | Traceability completa. |
| CA-105-32 | PASS | DOC | 11 | Verdict coerente: DONE / OWNER_OPERATOR_ACCEPTED. |

## Conteggio

- PASS/PASS_NOT_APPLICABLE: 28
- PASS_WITH_NOTES: 4
- BLOCKED: 0
- NOT_RUN non mascherati: 0 per le note real-ops bloccanti.
- Note accettate non bloccanti: CA-105-12 advisor Supabase legacy/Ops; CA-105-17 warning legacy; CA-105-23 background/interrupt reale non rieseguito da Codex ma annulla/retry confermati; CA-105-26 audit assistive completo non rieseguito.
