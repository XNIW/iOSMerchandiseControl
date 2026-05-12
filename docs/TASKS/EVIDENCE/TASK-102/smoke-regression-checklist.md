# TASK-102 Smoke Regression Checklist

| Flusso | Stato | Tipo | Evidenza / nota |
|--------|-------|------|-----------------|
| Home/navigation | PASS | BUILD/SIM/AX | Home e tab shell campionati su iPhone 17 Pro iOS 26.4 con Dynamic Type `extra-large`; nessun blocker di navigazione. |
| Import Excel | PASS WITH NOTES | BUILD/SIM | Picker Files aperto; import sintetico verificato tramite handoff file app con XLSX privacy-safe. Il provider Files Simulator non mostrava il file host per selezione diretta. |
| PreGenerate | PASS | BUILD/SIM/AX | PreGenerate aperta da import sintetico; ruoli/colonne/supplier/category e CTA `Genera` verificati. |
| GeneratedView | PASS | BUILD/SIM/AX/TEST | GeneratedView verificata dopo import e manual entry; summary, righe, scanner/search, bulk action e row detail PASS; full XCTest Debug PASS. |
| Dettaglio riga | PASS | SIM/AX | Sheet dettaglio/modifica riga aperto con dati sintetici; chiusura e azioni non bloccanti. |
| Inserimento manuale | PASS | SIM/AX | Manual entry con dati sintetici verificato; `Aggiungi e continua` PASS. |
| Scanner fallback | PASS WITH NOTES | SIM/AX | Permission denied in Simulator e fallback “Inserisci manualmente” verificati; ricerca manuale alternativa PASS. Scansione camera reale resta hardware-device-only. |
| Cronologia | PASS | BUILD/SIM/AX/TEST | Cronologia verificata con entry sintetiche import/manual; filtro, status e azioni principali leggibili. |
| Database CRUD | PASS | BUILD/SIM/AX/TEST | Create/read/update/delete con dati sintetici PASS; delete confirmation PASS; storico prezzi apribile/chiudibile dopo fix. |
| Import/export DB | PASS WITH NOTES | SIM/TEST | Export share sheet aperto; import options e file picker surface verificati. Import full DB mutativo non applicato per provider file vuoto. |
| Sync/manual cloud surface esistente | PASS WITH NOTES | BUILD/SIM/AX | Options/sync signed-out surface verificata; sync live reale non eseguito per evitare dati/backend reali. |

## Final smoke summary

- Build finale Release + launch simulator: PASS, warnings/errors 0.
- Full XCTest Debug finale: PASS 652 tests / 0 failed / 12 skipped.
- Simulator privacy-safe campionato: Home/navigation, PreGenerate, GeneratedView, dettaglio riga, manual entry, scanner fallback/search, Cronologia, Database CRUD, import/export surface, Options/sync signed-out.
- Import reale da Files provider host e sync live restano PASS WITH NOTES per limiti ambiente/privacy; handoff file app, fallback e superfici UI verificati con dati sintetici.

## Review finale 2026-05-12 15:52 -0400

- `git diff --check`: PASS.
- Release build + launch simulator post-review: PASS su iPhone 15 Pro Max iOS 26.1, warnings/errors 0.
- Full XCTest Debug post-review: primo run bloccato da CoreSimulator clone su iPhone 15 Pro Max; retry su iPhone 17 Pro PASS **640 passed / 0 failed / 12 skipped**.
- Scanner fallback: review statica conferma che il fallback principale porta a manual entry/search quando non deve riaprire il dettaglio riga.
- Database CRUD: review statica conferma che le azioni interne row restano accessibili e il delete confirmation flow resta invariato.
- Decisione smoke: **PASS WITH NOTES**; file picker, camera permission runtime, import/export manuale, CRUD manuale con fixture e sync live reale restano non interagiti.

## Chiusura finale 2026-05-12 16:46 -0400

- Ultimo pass manuale in Simulator completato con dati sintetici privacy-safe: i limiti rimasti nella review 15:52 sono stati ridotti a soli limiti non bloccanti hardware/file-provider/sync-live.
- Scanner permission denied + fallback manuale, CRUD Database, export share sheet, import surface, PreGenerate/GeneratedView e History sono stati interagiti manualmente.
- Decisione finale smoke: **PASS WITH NOTES** per camera reale hardware-device-only, full VoiceOver gestuale non eseguito, provider Files Simulator vuoto e sync live non eseguito.
