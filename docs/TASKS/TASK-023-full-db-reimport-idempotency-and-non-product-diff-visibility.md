# TASK-023: Full-database reimport idempotency + non-product diff visibility

## Informazioni generali
- **Task ID**: TASK-023
- **Titolo**: Full-database reimport idempotency + non-product diff visibility
- **File task**: `docs/TASKS/TASK-023-full-db-reimport-idempotency-and-non-product-diff-visibility.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-23
- **Ultimo aggiornamento**: 2026-03-23
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: TASK-022 completato
- **Sblocca**: comportamento affidabile e idempotente del reimport full-database; maggiore trasparenza dei delta non-product nel riepilogo di import

## Scopo
Fare in modo che il reimport dello stesso full database non reinserisca integralmente i dati gia' presenti di `PriceHistory` quando non esistono differenze reali, o che applichi solo il delta effettivamente nuovo/diverso. In parallelo, il flow di analysis/apply deve rendere visibili anche i delta non-product rilevanti del full import, cosi' che l'utente capisca cosa cambiera' davvero e non solo lato prodotti.

## Contesto
TASK-022 ha chiuso con successo il crash nel passaggio conferma -> apply del full-database import grande. Dopo la chiusura, i test manuali utente hanno evidenziato un problema diverso e fuori scope rispetto al crash: reimportando lo stesso file database completo, il lavoro effettivo puo' ricadere quasi tutto su `PriceHistory`, ma questo non appare in modo trasparente nella schermata di analisi prodotti. Per mantenere il perimetro minimo e rispettare l'etica del Vibe Coding, la correttezza/performance del reimport e la UX del progress vengono separati in due task distinti.

## Evidenza principale
- Test manuale utente: reimport dello stesso file database completo piu' volte.
- Nella schermata di analisi prodotti i conteggi possono risultare a zero o comunque non spiegare il lavoro reale dell'import.
- Rimuovendo il foglio `PriceHistory`, l'operazione finisce subito.
- Log rilevante osservato sul reimport invariato: `phase=apply_price_history elapsed=150.92s rows=34726 inserted=34726 skipped=0`.
- Conclusione operativa: oggi il reimport non e' idempotente per lo storico prezzi, introduce costo inutile e rende poco trasparente il delta non-product realmente applicato.

## Non incluso
- UX avanzata di progress/cancel.
- Refactor largo del parser Excel o della pipeline multi-sheet fuori necessita' reale.
- Nuovi redesign della schermata di analisi oltre quanto serve per rendere visibili i delta non-product rilevanti.
- Riaprire TASK-022 o TASK-011.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/Models.swift`

## Criteri di accettazione
- [ ] Reimportando lo stesso full database, `PriceHistory` non viene reinserito integralmente se non esistono differenze reali.
- [ ] I log distinguono chiaramente tra `inserted`, `skipped` e `already-present` durante l'apply di `PriceHistory`.
- [ ] Il tempo di apply sul reimport invariato non dipende piu' dal reinserimento completo di tutto `PriceHistory`.
- [ ] L'analysis o il riepilogo import rende visibili i delta non-product almeno dove sono rilevanti per il full import.
- [ ] Nessuna regressione sul primo import reale del full database.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Separare correttezza/performance del reimport da UX/progress | Un unico task "blob" per tutto il follow-up full-database | Riduce scope creep e mantiene il task focalizzato su dati/idempotenza e trasparenza dei delta | attiva |
| 2 | Trattare `PriceHistory` come punto primario del reimport invariato | Refactor ampio immediato su tutta la pipeline multi-sheet | L'evidenza principale punta al reinserimento integrale di `PriceHistory`; il resto va valutato solo se rilevante al delta utente-visibile | attiva |

## Handoff a Claude per planning
- **Fase corrente**: PLANNING
- **Prossima fase prevista**: PLANNING
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: definire un piano minimo per rendere idempotente o delta-aware l'apply di `PriceHistory` nel reimport full-database e per esporre nel riepilogo di import i delta non-product rilevanti, senza allargare il task a progress UX/cancellation.
