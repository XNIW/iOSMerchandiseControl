# TASK-024: Full-database import progress UX + cancellation

## Informazioni generali
- **Task ID**: TASK-024
- **Titolo**: Full-database import progress UX + cancellation
- **File task**: `docs/TASKS/TASK-024-full-db-import-progress-ux-and-cancellation.md`
- **Stato**: TODO
- **Fase attuale**: N/A
- **Responsabile attuale**: N/A
- **Data creazione**: 2026-03-23
- **Ultimo aggiornamento**: 2026-03-23
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: TASK-022 completato
- **Sblocca**: UX piu' leggibile e controllabile per il full-database import su dataset grandi

## Scopo
Migliorare il dialog `Importazione in corso...` del full-database import con un progresso piu' leggibile, la fase corrente, contatori o messaggi utili e la valutazione di un bottone `Annulla` con semantica sicura per l'apply.

## Contesto
Durante i test manuali del full-database import grande, l'overlay attuale risulta molto generico e non comunica bene che cosa stia accadendo mentre l'apply e' in corso. Per evitare di mescolare correttezza dati/performance con miglioramenti UX, questo lavoro viene tenuto separato da TASK-023 e resta per ora nel backlog come follow-up dedicato.

## Evidenza principale
- L'overlay attuale mostra solo uno spinner con il messaggio `Importazione in corso...`.
- Su dataset grandi l'apply puo' durare abbastanza a lungo da richiedere maggiore trasparenza sullo stato reale.
- La semantica di eventuale cancellazione va trattata separatamente dalla logica di dedup/delta del reimport full-database.

## Non incluso
- Dedup o delta logic di `PriceHistory` come obiettivo principale.
- Visibilita' dei delta non-product come problema di correttezza dati.
- Refactor largo del parser/import pipeline fuori dalle esigenze del progress UI.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/LocalizationManager.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

## Criteri di accettazione preliminari
- [ ] L'overlay di import mostra almeno fase corrente e progresso leggibile per il full-database import.
- [ ] L'utente riceve un messaggio piu' utile del semplice spinner generico nei passaggi lunghi.
- [ ] Se viene introdotta un'azione `Annulla`, la sua semantica e' sicura e coerente con lo stato dell'apply.
- [ ] Il task non diventa il contenitore della logica di idempotency/delta del reimport, che resta in TASK-023.

## Nota di backlog
Task volutamente NON attivo. Va pianificato separatamente solo dopo il consolidamento del follow-up di correttezza/performance tracciato in TASK-023 o su decisione esplicita dell'utente.
