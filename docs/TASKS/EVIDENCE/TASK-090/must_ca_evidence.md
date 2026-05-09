# TASK-090 — Must / Should / Could / Out e CA evidence

Timestamp locale: 2026-05-09 17:10 -0400

## Must / Should / Could / Out

| Priorità | Esito | Evidenza |
|----------|-------|----------|
| Must — matrice acceptance compilata | PASS | `matrix_s90_f_initial.md` e `matrix_s90_f_final.md` |
| Must — percorso verificabile catalogo + ProductPrice | PARTIAL | Catalogo verificato staticamente/build/test e da TASK-087 prior runtime; ProductPrice PASS con TASK-088 prior runtime + regressioni correnti |
| Must — stato cicli Android <-> Supabase <-> iOS chiaro | PASS | Scenari cross-platform marcati PARTIAL con motivazione; nessun PASS narrativo |
| Must — UI/copy veritiera | PASS | `static_ui_copy_audit.md`, `plutil`, XCTest/localization/static review |
| Must — privacy/anti-distruttivo/anti-automation | PASS | `privacy_boundary_log.md`, secret scan, no code patch, no live write |
| Should — smoke runtime `TASK090_*` | BLOCKED_ENV | Owner/session e collision scan DB non verificati immediatamente prima di write sicuro |
| Should — import/export round-trip runtime | PARTIAL | Static review + TASK-089 evidence; UI manual app-file-app non rieseguito |
| Should — retry/idempotenza | PARTIAL | ProductPrice PASS; cross-platform fresh runtime non rieseguito |
| Should — audit UX statico/screenshot | PASS statico | `static_ui_copy_audit.md`; screenshot non prodotti perché non necessari senza patch UI |
| Could — timing leggero | SKIPPED | TASK-089 copre benchmark; duplicare runtime non aggiunge evidenza proporzionata |
| Could — UI polish | SKIPPED | Nessun copy falso o blocker UI emerso; zero patch Swift |
| Could — Android reference extra | SKIPPED | Android resta riferimento funzionale; TASK-087/TASK-088 già documentano evidenze utili |
| Out — redesign/Kotlin/SQL/RLS/full benchmark/claim 100% | PASS | Nessun intervento fuori perimetro eseguito |

## CA-T090

| CA | Esito | Evidenza |
|----|-------|----------|
| CA-T090-01 | PASS | Manifest acceptance creato prima dei run finali |
| CA-T090-02 | PASS | Ogni scenario finale ha status e motivo |
| CA-T090-03 | PARTIAL | Cicli bidirezionali coperti da TASK-087 prior runtime; nessun nuovo `TASK090_*` live per gate ambiente |
| CA-T090-04 | PASS | ProductPrice current/previous e zero duplicati da TASK-088 + test correnti |
| CA-T090-05 | PARTIAL | Import/export letto/statico + TASK-089 synthetic; round-trip UI non rieseguito |
| CA-T090-06 | PASS | Audit copy Release e localizzazioni PASS |
| CA-T090-07 | PASS | ViewModel/summary e servizi fail-closed espongono blocked/skipped/conflict; XCTest PASS |
| CA-T090-08 | PASS | Evidence privacy-safe; nessun dato reale/segreto/write live |
| CA-T090-09 | PASS | Nessun claim production-ready globale o 100% |
| CA-T090-10 | PASS | Nessuna sync automatica/background/Timer/BGTask/Realtime/polling/worker introdotta |
| CA-T090-UX-01 | PASS | Audit statico UX/UI completato |
| CA-T090-UX-02 | PASS | Nessuna scelta UI alternativa richiede patch; stile iOS esistente confermato |
| CA-T090-UX-03 | PASS | CTA/copy specifiche e non fuorvianti |
| CA-T090-EFF-01 | PASS | Servizi verificati con fingerprint, batching/paging/guards; nessun refactor richiesto |
| CA-T090-EFF-02 | PARTIAL | Feedback/progress/cancel/retry presenti staticamente; nessun nuovo runtime medio/grande |
| CA-T090-SAFE-01 | PASS | Nessuna decisione UX ha autorizzato write o migration |
| CA-T090-MATRIX-01 | PASS | Matrice finale compilata con evidenze e stati |
| CA-T090-MATRIX-02 | PASS | Scenario non eseguiti motivati come PARTIAL/BLOCKED_ENV/SKIPPED |
| CA-T090-PERF-01 | PARTIAL | Evidenza statica di progress/cancel; benchmark non duplicato |
| CA-T090-RETRY-01 | PARTIAL | ProductPrice idempotenza PASS; cross-platform fresh runtime non rieseguito |
| CA-T090-BOUNDARY-01 | PASS | Nessun bisogno di Kotlin/SQL/redesign emerso nel perimetro attuale |
| CA-T090-PRIORITY-01 | PASS | Must/Should/Could/Out finali separati |
| CA-T090-A11Y-01 | PASS | Nessun ritocco UI; audit statico non trova label fuorvianti nel perimetro Release |
| CA-T090-DOD-01 | PASS | Handoff separa PASS/PARTIAL/BLOCKED_ENV/SKIPPED |

## Review closure

Timestamp locale: 2026-05-09 17:26 -0400

Decisione review: **DONE / Chiusura — PARTIAL_ACCEPTED**.

La review accetta i residui **PARTIAL / BLOCKED_ENV / SKIPPED** come limiti espliciti e non bloccanti per TASK-090:

- nuovo smoke live `TASK090_*` non eseguito per gate owner/session/collision non verificati;
- Android runtime fresh non rieseguito perche' Android resta riferimento funzionale;
- import/export UI manuale app -> file -> app non rieseguito, coperto solo da audit statico e TASK-089 synthetic evidence;
- nessun claim production-ready globale o 100%.
