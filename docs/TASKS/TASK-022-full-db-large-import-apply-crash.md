# TASK-022: Full-database large import: apply crash after analysis (EXC_BAD_ACCESS)

## Informazioni generali
- **Task ID**: TASK-022
- **Titolo**: Full-database large import: apply crash after analysis (EXC_BAD_ACCESS)
- **File task**: `docs/TASKS/TASK-022-full-db-large-import-apply-crash.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-23
- **Ultimo aggiornamento**: 2026-03-23
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: nessuno (task autonomo, estratto da TASK-011 dopo test reali di TASK-006)
- **Sblocca**: TASK-006 (blocco pratico attuale); eventuale ripresa del perimetro piu' ampio di TASK-011

## Scopo
Isolare e risolvere il crash specifico osservato nel full-database import con dataset grande dopo il completamento apparente dell'analysis, nella transizione verso l'apply e la costruzione del payload, garantendo un esito deterministico e leggibile dall'utente: completamento corretto oppure errore gestito, mai crash.

## Contesto
Durante i test manuali di TASK-006 con un file Excel reale molto grande, l'analysis completa sembra arrivare al termine ma il flusso non conclude l'apply in modo affidabile. Per decisione utente del 2026-03-23, TASK-011 viene sospeso e questo blocker concreto, riproducibile e piu' specifico viene estratto in un task dedicato. User override esplicito: backlog e tracking vengono riallineati da Codex su richiesta dell'utente.

## Evidenza principale
- Dataset grande reale usato in import full-database da file Excel.
- L'analysis completa sembra terminare correttamente.
- I log riportano circa `16.788` righe `Products` analizzate e circa `34.726` righe `PriceHistory` parse.
- In UI resta visibile a lungo l'overlay `Importazione in corso...` senza completamento.
- In debugger il crash osservato e' `EXC_BAD_ACCESS` dentro `DatabaseView.makeImportApplyPayload(...)`.
- Il punto evidenziato e' la costruzione del payload di apply, in particolare la conversione `analysis.newProducts.map(ImportProductDraftSnapshot.init)` e `analysis.updatedProducts.map(ImportProductUpdateSnapshot.init)`.

## Non incluso
- Risolvere l'intero umbrella di TASK-011 su large import stability, memory e progress UX oltre quanto necessario per questo crash specifico.
- Refactor ampio dell'architettura di import o della pipeline Excel non strettamente richiesto dal fix.
- Modifica del formato XLSX multi-sheet, dell'export database o del supporto ad altri formati.
- Lavoro su scenari non large-import, salvo i controlli minimi di non regressione sui file piccoli.
- Chiusura finale di TASK-006 o riapertura operativa di TASK-011.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` — `makeImportApplyPayload`, `ImportApplyPayload`, `applyConfirmedImportAnalysis`, orchestrazione apply e stato progress.
- `iOSMerchandiseControl/ImportAnalysisView.swift` — struttura `ProductImportAnalysisResult` e feedback UI tra analisi completata e apply.

## Criteri di accettazione
- [ ] **CA-1**: Nessun crash `EXC_BAD_ACCESS` durante l'apply del full-database import con dataset grande reale dopo analysis completata.
- [ ] **CA-2**: `makeImportApplyPayload(...)` non materializza strutture tali da causare crash o memory spike incontrollato sul dataset grande reale.
- [ ] **CA-3**: L'utente distingue chiaramente se l'apply e' ancora in corso oppure e' terminato; l'overlay/progress non resta in stato ambiguo o apparentemente bloccato senza esito.
- [ ] **CA-4**: L'import full-database grande completa correttamente oppure fallisce con errore gestito e messaggio esplicito; non termina mai con crash.
- [ ] **CA-5**: Nessuna regressione sui file piccoli: l'import full-database e i percorsi di apply ordinari continuano a funzionare come prima.
- [ ] **CA-6**: Build compila senza errori e senza warning nuovi.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Separare il crash specifico di apply in un task dedicato | Continuare a trattarlo dentro TASK-011 | Il problema e' concreto, riproducibile e blocker immediato; un task separato riduce ambiguita' di perimetro e sblocca il tracking di TASK-006 | attiva |

---

## Handoff a Claude per planning
- **Fase corrente**: PLANNING
- **Responsabile richiesto**: CLAUDE
- **Azione richiesta**: definire un planning minimo e focalizzato sul crash specifico di apply post-analysis, mantenendo separato questo perimetro dal resto di TASK-011 e partendo dall'evidenza raccolta su dataset grande reale.
