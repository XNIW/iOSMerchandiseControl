# TASK-011: Large import stability, memory e progress UX

## Informazioni generali
- **Task ID**: TASK-011
- **Titolo**: Large import stability, memory e progress UX
- **File task**: `docs/TASKS/TASK-011-large-import-stability-and-progress.md`
- **Stato**: TODO
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-03-21
- **Ultimo aggiornamento**: 2026-03-21
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: TASK-006 (il problema è emerso durante i test di TASK-006; il codice di import multi-sheet di TASK-006 è il contesto principale)
- **Sblocca**: TASK-006 (sblocco pratico: TASK-006 può essere validato manualmente solo dopo che TASK-011 risolve il problema di stabilità)

## Scopo
Rendere l'import di dataset molto grandi (migliaia di prodotti) stabile, non bloccante per l'UI e con progress reporting chiaro, senza causare freeze, memory pressure o app kill. Il task copre il flusso `importFullDatabaseFromExcel` (multi-sheet, TASK-006) e indirettamente anche `importProductsFromExcel` (singolo-sheet) che condivide la logica di apply.

## Contesto
Durante i test di TASK-006 è emerso che l'import di dataset molto grandi (ordine di grandezza: migliaia di prodotti, decine di migliaia di record PriceHistory) causa instabilità:
- **App kill per memoria**: iOS termina il processo durante l'analisi o l'apply per OOM (Out Of Memory)
- **EXC_BAD_ACCESS**: crash durante operazioni SwiftData sotto pressione di memoria
- **UI congelata**: il thread principale è bloccato durante tutto il parsing e l'apply; l'utente non riceve feedback
- **Progress UX incoerente**: nessuna progress indication durante le fasi lunghe; l'app appare bloccata

L'implementazione attuale esegue parsing, analisi e apply interamente sul main thread in modo sincrono, senza chunking, senza autorelease pool, e senza nessuna indicazione di progresso persistente.

## Non incluso
- Modifica del formato XLSX multi-sheet (rimane com'è da TASK-006)
- Modifica degli entry point UI (già definiti da TASK-006)
- Ottimizzazione dell'export (non è il collo di bottiglia)
- Refactor completo dell'architettura di import (solo le modifiche minime necessarie per la stabilità)
- Streaming parser XLSX (complessità elevata, fuori perimetro)
- Supporto a file .xls legacy multi-sheet
- Localizzazione messaggi di progresso
- Gestione di file corrotti oltre quanto già gestito

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` — orchestrazione import, `analyzeImport`, `applyImportAnalysis`, `applyPendingPriceHistoryImport`, `importNamedEntitiesSheet`; aggiunta progress state
- `iOSMerchandiseControl/ImportAnalysisView.swift` — rendering della lista prodotti da analizzare; potenziale problema di rendering con migliaia di righe
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — `ExcelAnalyzer.readSheetByName` e analisi righe; già carica tutto in memoria, ma potenziale ottimizzazione del parsing

## Criteri di accettazione
- [ ] **CA-1**: Import di un file con almeno 5.000 righe Products completa senza app kill né crash (EXC_BAD_ACCESS o OOM) su un device/simulatore con memoria limitata
- [ ] **CA-2**: Durante l'analisi (parsing + analyzeImport) l'UI non è completamente bloccata: è visibile almeno un indicatore di attività (spinner o ProgressView)
- [ ] **CA-3**: Durante l'apply (applyImportAnalysis + applyPendingPriceHistoryImport) l'UI mostra un progress indicator; l'utente percepisce che l'operazione è in corso
- [ ] **CA-4**: L'apply di 5.000 prodotti nuovi completa correttamente (tutti i record salvati nel database) senza errori SwiftData intermedi
- [ ] **CA-5**: L'apply di 50.000 record PriceHistory completa correttamente senza crash
- [ ] **CA-6**: Tutte le funzionalità di import esistenti (singolo-sheet, CSV, multi-sheet) continuano a funzionare correttamente su dataset piccoli (< 500 righe) — nessuna regressione
- [ ] **CA-7**: La UI di ImportAnalysisView non causa freeze né crash visibile con 5.000 righe di analisi mostrate
- [ ] **CA-8**: Build compila senza errori e senza warning nuovi

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | — | — | — | — |

---

## Planning (Claude)

### Analisi

#### Root cause candidate

**1. Sincronicità sul main thread**
`importFullDatabaseFromExcel`, `analyzeImport`, `applyImportAnalysis` e `applyPendingPriceHistoryImport` sono tutti chiamati sul main thread in modo sincrono. Con dataset grandi, il thread principale è bloccato per secondi o minuti, rendendo la UI irresponsiva e aumentando la probabilità che iOS consideri l'app come "hung" o la termini per memory pressure.

**2. Memoria non rilasciata durante apply**
`applyImportAnalysis` itera su `analysis.newProducts` e `analysis.updatedProducts` in un singolo loop senza autorelease pool e con un unico `context.save()` finale. Con migliaia di record, tutti gli oggetti Swift/SwiftData intermedi rimangono vivi in memoria fino alla fine del loop, causando picchi di memoria.

**3. Single batch save SwiftData**
Un `context.save()` su migliaia di insert è un'operazione lunga che:
- Mantiene in memoria tutti gli oggetti non ancora flushed
- Può fallire con OOM se la dirty page cache di SwiftData supera i limiti
- Non libera memoria intermedia

**4. Rendering illimitato in ImportAnalysisView**
`ImportAnalysisView` probabilmente mostra tutti i prodotti nuovi/aggiornati in una `List` senza virtualizzazione o limiti. Con migliaia di elementi, il rendering iniziale può causare un picco di memoria e rallentare l'interfaccia.

**5. Memory pressure da parsing XLSX**
`readSheetByName` carica l'intero foglio in un `[[String]]` in memoria prima di passarlo a `analyzeSheetRows`. Con un foglio da 50.000 righe e 9 colonne, questo può occupare decine di MB solo per le stringhe.

#### Stato del codice rilevante

- `importFullDatabaseFromExcel` (DatabaseView.swift): sincrono, main thread, chiama `parsePendingPriceHistoryContext` (che carica tutte le righe PriceHistory in RAM), poi imposta `importAnalysisResult` che triggera la UI
- `applyImportAnalysis` (DatabaseView.swift): loop su `newProducts`/`updatedProducts`, unico `context.save()` alla fine
- `applyPendingPriceHistoryImport` (DatabaseView.swift): loop su tutte le entries, unico `context.save()` alla fine
- `ImportAnalysisView` (ImportAnalysisView.swift): lista che mostra `newProducts` e `updatedProducts` senza paginazione

### Approccio proposto

#### Strategia generale
Minimo cambiamento necessario: non riscrivere l'architettura, ma rendere le operazioni lunghe non-bloccanti per il main thread e chunking degli apply per ridurre i picchi di memoria.

#### STEP 1 — Chunked apply con autorelease pool

Modificare `applyImportAnalysis` e `applyPendingPriceHistoryImport` per processare i record in batch di dimensione fissa (es. 200 per i prodotti, 500 per PriceHistory) con:
- `autoreleasepool { ... }` attorno a ogni batch per rilasciare gli oggetti intermedi
- `try context.save()` alla fine di ogni batch (non solo alla fine del loop)
- Questo riduce il picco di memoria mantenendo la stessa semantica

```swift
// Pattern target per apply in batch
let batchSize = 200
for batch in stride(from: 0, to: items.count, by: batchSize) {
    let chunk = items[batch..<min(batch + batchSize, items.count)]
    try autoreleasepool {
        for item in chunk {
            // ... insert/update
        }
        try context.save()
    }
}
```

#### STEP 2 — Offload dal main thread

Spostare `importFullDatabaseFromExcel` (la parte di parsing e analisi) su un background task:
- Usare `Task { }` (concurrency Swift) per il parsing pesante
- Aggiornare la UI (progress state, importAnalysisResult) solo sul main thread tramite `await MainActor.run { }`
- Questo richiede che il modelContext sia usato solo sul MainActor (già così con `@Environment(\.modelContext)`)

**Nota**: il parsing (readSheetByName, analyzeSheetRows) è CPU-bound e non richiede accesso al modelContext, quindi può andare su background. L'apply richiede il modelContext, quindi deve stare sul main thread ma può essere "yielding" verso il loop di eventi tramite yield espliciti o chunking.

#### STEP 3 — Progress state

Aggiungere `@State private var importProgress: ImportProgress?` in DatabaseView per trasmettere lo stato all'utente:

```swift
enum ImportProgress {
    case parsing
    case analyzing
    case applying(current: Int, total: Int)
    case applyingPriceHistory(current: Int, total: Int)
}
```

Mostrare un overlay con `ProgressView` durante le fasi lunghe, con messaggio descrittivo. La UI di ImportAnalysisView può restare invariata (l'utente la vede solo dopo l'analisi).

#### STEP 4 — Limite display in ImportAnalysisView

Se la lista delle righe in ImportAnalysisView supera una soglia (es. 2.000 elementi), troncare il display mostrando solo i primi N con un banner "Mostrando i primi N di M totali". L'apply funziona comunque sull'intero dataset. Questo evita il picco di rendering.

### File da modificare
| File | Tipo modifica | Motivazione |
|------|---------------|-------------|
| `DatabaseView.swift` | Chunked apply con autoreleasepool + save per batch; Task {} per parsing; @State progress | Root cause 1, 2, 3 |
| `ImportAnalysisView.swift` | Limite display righe con banner informativo | Root cause 4 |

### Rischi identificati
| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| Il modelContext non è thread-safe e non può essere usato su background thread | Alta | Alto | Mantenere l'accesso a modelContext solo sul main thread; spostare solo il parsing su background |
| Il chunked save con rollback parziale lascia il DB in stato inconsistente se il device va in OOM durante l'apply | Media | Medio | Documentare come comportamento noto; i batch già completati sono persistiti, quelli non completati no. Coerente con il comportamento best-effort già definito in TASK-006 |
| `autoreleasepool` in Swift concurrency non ha garanzie di timing | Bassa | Basso | Verificare empiricamente; se insufficiente, aggiungere yield espliciti |
| Il troncamento della lista in ImportAnalysisView confonde l'utente | Bassa | Basso | Il banner deve essere chiaro: "Mostrando i primi N di M. L'import includerà tutti i prodotti." |

### Piano di test manuale

**Dataset di test:**
- File piccolo: 100 prodotti, 500 PriceHistory (smoke test, nessuna regressione)
- File medio: 1.000 prodotti, 5.000 PriceHistory
- File grande: 5.000 prodotti, 50.000 PriceHistory (test principale per CA-1/CA-4/CA-5)

1. **Test smoke (regression)**: importare file piccolo con import singolo-sheet e multi-sheet → verificare comportamento invariato rispetto a TASK-006
2. **Test memoria media**: importare file con 1.000 prodotti → verificare nessun crash, progress visibile, apply corretto
3. **Test grande**: importare file con 5.000 prodotti + 50.000 PriceHistory → verificare: nessun app kill, progress visibile, tutte le righe salvate nel DB
4. **Test UI**: aprire ImportAnalysisView con 5.000 righe → verificare nessun freeze, banner di troncamento visibile se applicabile
5. **Test apply parziale**: durante apply su dataset grande, simulare memory pressure (aprire altre app sul device) → verificare che l'app non venga killata o che gestisca il caso in modo accettabile

### Criteri per sbloccare TASK-006
Dopo il completamento di TASK-011, TASK-006 può essere ripreso e la validazione manuale dei test rimanenti (CA-13 round-trip, stabilità su dataset reali) può avvenire senza il rischio di crash.

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: Implementare in ordine: (1) chunked apply con autoreleasepool in applyImportAnalysis e applyPendingPriceHistoryImport, (2) offload parsing su Task {}, (3) progress state e ProgressView overlay, (4) limite display in ImportAnalysisView. Testare con il dataset da 5.000 prodotti come verifica principale. Non modificare il formato XLSX né la logica di import multi-sheet definita in TASK-006.

---

## Execution (Codex)

### Obiettivo compreso
[Da compilare]

### File controllati
[Da compilare]

### Piano minimo
[Da compilare]

### Modifiche fatte
[Da compilare]

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: [stato]
- [ ] Nessun warning nuovo: [stato]
- [ ] Modifiche coerenti con planning: [stato]
- [ ] Criteri di accettazione verificati: [stato]

### Rischi rimasti
[Da compilare]

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: [Da compilare]

---

## Review (Claude)

### Problemi critici
[Da compilare]

### Problemi medi
[Da compilare]

### Miglioramenti opzionali
[Da compilare]

### Fix richiesti
[Da compilare]

### Esito
[Da compilare]

### Handoff → Fix (se CHANGES_REQUIRED)
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: [Da compilare]

---

## Fix (Codex)

### Fix applicati
[Da compilare]

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: [stato]
- [ ] Fix coerenti con review: [stato]
- [ ] Criteri di accettazione ancora soddisfatti: [stato]

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i fix applicati

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- Streaming parser XLSX per ridurre ulteriormente il footprint di memoria durante il parsing (richiede refactor significativo di ExcelAnalyzer, fuori scope di questo task)
- Cancellazione dell'import in corso da parte dell'utente (pulsante "Annulla" durante il progress) — fuori scope, feature separata
- Deduplicazione logica import tra ProductImportViewModel e DatabaseView — già segnalata in TASK-006 come follow-up preesistente

### Riepilogo finale
[Da compilare]

### Data completamento
[Da compilare]
