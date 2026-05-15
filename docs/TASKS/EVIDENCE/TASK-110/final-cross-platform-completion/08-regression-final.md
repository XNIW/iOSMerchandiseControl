# TASK-110 final cross-platform completion - 08 regression final

Data: 2026-05-15  
Verdict: **PASS**, con note non bloccanti per test hardware/manuali non disponibili nel pass finale.

## Smoke eseguiti

| Area | Tipo | Evidenza | Esito |
|------|------|----------|-------|
| Login/logout iOS | SIM | OAuth logout/login/re-login e restore session PASS | PASS |
| Login/logout Android | EMU | Google sign-in/logout/re-login e force-stop restore PASS | PASS |
| Sync now | SIM/EMU | Sync ripetuti entrambi, no duplicate/no stale cancelled | PASS |
| Cronologia | SIM/EMU/DB | create/update/delete bidirezionale + tombstone PASS | PASS |
| Database prodotti | SIM/EMU/DB | prodotto `TASK110_FINAL_BARCODE_1652` bidirezionale PASS | PASS |
| Storico prezzi | SIM/EMU/DB | ProductPrice append-only 23.45 -> 34.56, counts 41111 | PASS |
| Fornitori/categorie | DB/APP | counts coerenti; nessun drift remoto TASK-110 | PASS |
| Opzioni lingua/tema | STATIC/TEST | localizzazioni lint/test PASS; nessun codice tema toccato | PASS |
| Generated sheet | TEST | History runtime summary empty-grid fix/test; nessun crash finale | PASS |
| Import Excel | TEST | regressione iOS benchmark/manual sync suite PASS; codice import non toccato | PASS_WITH_NOTES |
| Export/share Excel | STATIC | codice export/share non toccato; nessuna regressione osservata in build/test | PASS_WITH_NOTES |
| Scanner barcode | STATIC | codice scanner non toccato; device/camera non disponibile operativamente | PASS_WITH_NOTES |
| Manual product insert | SIM/EMU | prodotto test creato/modificato su Android e visto da iOS/Supabase | PASS |

## Note PASS_WITH_NOTES

- File picker/export/share e camera fisica non sono stati rieseguiti manualmente end-to-end in questo pass finale; non sono stati toccati dal diff TASK-110 finale e non risultano regressioni da build/test.
- Device fisici: iPhone offline via `xctrace`; Android fisico bloccato da keyguard sicuro. Simulator/emulator sono stati usati per la matrice runtime completa.

## Regressioni trovate e corrette

- iOS crash su History con grid vuota derivata da offline Android: corretto e ritestato.
- iOS stale review per metadata-only/stock-only Product diff: corretto e ritestato con preview `updates=0`, `priceSignals=0`.
- iOS ProductPrice push non aggiornava il mirror `inventory_products.retail_price`: corretto e verificato con Supabase/Android.

