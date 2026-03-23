# TASK-014: Global Audit & Backlog Refresh

## Informazioni generali
- **Task ID**: TASK-014
- **Titolo**: Global Audit & Backlog Refresh — revisione parity iOS/Android e aggiornamento backlog
- **File task**: `docs/TASKS/TASK-014-global-audit-backlog-refresh.md`
- **Stato**: DONE
- **Fase attuale**: DONE
- **Responsabile attuale**: N/A
- **Data creazione**: 2026-03-22
- **Ultimo aggiornamento**: 2026-03-22
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: TASK-001 (gap audit originale, usato come baseline)
- **Sblocca**: TASK-015 … TASK-021 (nuovi task proposti nel backlog)

## Scopo
Revisione globale approfondita del progetto: verifica coerenza tracking/filesystem, audit completo iOS vs Android per intero flusso utente, audit architetturale e robustezza, identificazione di gap residui, debiti tecnici, edge case rischiosi e opportunità iOS-specifiche; aggiornamento del backlog con task nuovi ben definiti e pronti per i prossimi cicli Claude → Codex.

## Contesto
Dal gap audit originale (TASK-001, 2026-03-19) sono stati implementati 13/17 gap (con 3 parziali). Il progetto ha numerosi task BLOCKED per test manuali sospesi. Questo audit amplia il perimetro rispetto a TASK-001 per includere: flussi operativi completi, comportamenti edge case, qualità architetturale, stabilità su dataset reali, e opportunità iOS-native.

## Non incluso
- Codice applicativo (nessuna modifica Swift)
- Review di task esistenti (restano nei loro stati attuali)
- Test manuali
- Execution di nuovi task
- Riapertura di task DONE
- Feature non core (stampa, multi-utente, notifiche push, OCR)

## File esaminati (sola lettura)
- `docs/MASTER-PLAN.md` + tutti `docs/TASKS/*.md` + `AGENTS.md` + `CLAUDE.md`
- Codebase iOS: tutti i `.swift` in `iOSMerchandiseControl/`
- Repo Android: `MerchandiseControlSplitView` — FilePickerScreen, PreGenerateScreen, GeneratedScreen, DatabaseScreen, HistoryScreen, OptionsScreen, ExcelViewModel, DatabaseViewModel, InventoryRepository

## Criteri di accettazione
- [x] CA-1: Incoerenze tracking documentate e corrette
- [x] CA-2: Audit parity iOS vs Android per intero flusso utente
- [x] CA-3: Audit architetturale e tecnico con classificazione debiti
- [x] CA-4: Audit robustezza ed edge case con marker di confidenza
- [x] CA-5: Audit opportunità iOS-specifiche
- [x] CA-6: Backlog aggiornato con nuovi task operativi (TASK-017..021)
- [x] CA-7: Matrice conversione gap/debt → task / deferred / wont_do
- [x] CA-8: Classifica priorità per prossimi cicli
- [x] CA-9: Nessun codice applicativo modificato
- [x] CA-10: Handoff compilato

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Task di solo planning/audit | Audit + fix immediato | Separazione netta planning/execution | attiva |
| 2 | TASK-002 chiuso come DONE parziale — "Condividi/Invia copia" funziona; "Apri con" cross-app documentato come limite iOS noto | Mantenere BLOCKED; nuovo task investigazione | Decisione utente 2026-03-22 (Decisione A = opzione a) | chiusa |
| 3 | TASK-015 (Calculate dialog) marcato WONT_DO — non richiesto dagli utenti attuali; GAP-15 documentato nell'audit | Implementare; lasciare TODO | Decisione utente 2026-03-22 (Decisione B = WONT_DO) | chiusa |
| 4 | TASK-016 (deduplication import) LOW, dopo TASK-005+TASK-006 DONE | Fare ora | Refactor su codice ancora in lavorazione aumenta rischio | attiva |
| 5 | TASK-017..021 aggiunti al backlog | Ignorare nuovi gap | Gap concreti emersi dall'audit approfondito | attiva |
| 6 | Filtri data History: report Android era errato | Aprire task duplicato | TASK-007 è DONE; i filtri esistono già su iOS | attiva |
| 7 | TASK-019 mantenuto unico (3 fix raggruppati) | Split in 3 task separati | I singoli fix sono troppo piccoli per un ciclo planning/execution separato; i rischi differenziati sono documentati nelle schede dei sotto-fix | attiva |

---

## Planning (Claude)

---

### ─── PARTE 0 — VERIFICA COERENZA TRACKING / FILESYSTEM ───

**Verifica eseguita il 2026-03-22 sul repo reale:**

| Elemento verificato | Risultato |
|--------------------|-----------|
| MASTER-PLAN stato globale | ✅ ACTIVE |
| MASTER-PLAN task attivo | ✅ TASK-014 / PLANNING / CLAUDE |
| MASTER-PLAN path file task attivo | ✅ `docs/TASKS/TASK-014-global-audit-backlog-refresh.md` esiste |
| TASK-017..021 nel backlog reale | ✅ Tutti presenti con stato TODO e priorità corrette |
| Path di tutti i task BLOCKED | ✅ Tutti i file esistono nel filesystem |
| TASK-TEMPLATE.md correttamente escluso | ✅ |

**Incoerenze trovate durante TASK-014 — con indicazione di tipo intervento:**

| ID | Incoerenza | Tipo intervento | Risultato |
|----|-----------|-----------------|-----------|
| INCOER-01 | TASK-008 assente dalla sezione "Task bloccati non attivi" del MASTER-PLAN | **Correzione applicata** — sezione aggiornata nel corso di TASK-014 | ✅ MASTER-PLAN ora coerente |
| INCOER-02 | `EntryInfoEditor.swift` nel filesystem non citato da alcun task | **Solo documentazione** — il file era già presente e funzionante; nessun task retroattivo necessario; nessuna modifica applicata | ✅ Documentato, repo già coerente |
| INCOER-03 | Report Android (agent) affermava che iOS mancasse di filtri data in History | **Correzione al documento di audit** — l'errore era nel report, non nel codice; TASK-007 è DONE e i filtri esistono già | ✅ Audit corretto, repo già coerente |

---

### ─── PARTE 1 — PARITY AUDIT iOS vs ANDROID (FLUSSO COMPLETO) ───

#### 1.1 — Stato dei 17 GAP originali (TASK-001 baseline)

| GAP | Descrizione | Stato codebase | Task | Evidenza |
|-----|-------------|----------------|------|---------|
| GAP-01 | Append file in PreGenerate | ✅ | TASK-003 DONE | `appendRows(from:)` in ExcelSessionViewModel |
| GAP-02 | Reload file in PreGenerate | ✅ | TASK-003 DONE | `FilePickerMode.reload` in PreGenerateView |
| GAP-03 | Revert/Restore in GeneratedView | ⚠️ Parziale | TASK-004 DONE | Solo 1 livello implementato; Android ha 2. Vedere TASK-018. |
| GAP-04 | Mark All Complete | ✅ | TASK-004 DONE | `markAllComplete()` — iOS ha questa, Android manca |
| GAP-05 | Delete row in GeneratedView | ✅ | TASK-004 DONE | `deleteRow(at: rowIndex)` |
| GAP-06 | Error export in ImportAnalysis | ✅ | TASK-005 BLOCKED | `exportErrors()`, `exportErrorsToXLSX()` |
| GAP-07 | Full Database Export multi-sheet | ✅ | TASK-006 BLOCKED | `makeFullDatabaseXLSX()` → Products, Suppliers, Categories, Price History |
| GAP-08 | Full Database Import multi-sheet | ✅ | TASK-006 BLOCKED | `importFullDatabaseFromExcel()` |
| GAP-09 | History filtri avanzati | ✅ | TASK-007 DONE | DateFilter: currentMonth, previousMonth, customRange, DatePicker |
| GAP-10 | External file opening | ⚠️ Parziale | TASK-002 BLOCKED | "Condividi" OK; "Apri con" cross-app non affidabile |
| GAP-11 | Inline editing ImportAnalysis | ⚠️ Parziale | TASK-005 BLOCKED | Editing via sheet (EditProductDraftView); funzionale ma non inline nella lista |
| GAP-12 | Old price fields su Product | ✅ Alt. | TASK-009 BLOCKED | ProductPrice model usato; decisione corretta documentata in TASK-009 |
| GAP-13 | Search navigation next/prev | ✅ | TASK-004 DONE | SearchPanel con `navigateToNextResult/Prev()` |
| GAP-14 | Localizzazione UI | ✅ (test pending) | TASK-010 BLOCKED | LocalizationManager.swift, L(), .lproj per it/en/zh-Hans/es |
| GAP-15 | Calculate dialog | ❌ | TASK-015 TODO | Mai implementato; unico gap senza task nel backlog |
| GAP-16 | Manual row addition dialog | ✅ | TASK-008 BLOCKED | `ManualEntrySheet` struct in GeneratedView |
| GAP-17 | Price Backfill Worker | ✅ | TASK-009 BLOCKED | `PriceHistoryBackfillService.swift` + hook ContentView |

**Riepilogo parity originale**: 13 implementati, 3 parziali (GAP-03, GAP-10, GAP-11), 1 non implementato (GAP-15).

> **Nota su GAP-03**: TASK-004 ha implementato UN solo livello di revert (snapshot al caricamento della sessione corrente). Android ha DUE livelli: (1) allo stato dell'import originale, (2) al DB attuale. Se l'utente ha già autosalvato modifiche e riapre la sessione, lo snapshot iOS riflette le modifiche — non l'import originale. Gap residuo → TASK-018.

---

#### 1.2 — Nuovi gap emersi dall'audit approfondito

| ID | Flusso | Descrizione | iOS | Android | Severità | Confidenza |
|----|--------|-------------|-----|---------|----------|------------|
| N-01 | PreGenerate | Validazione esplicita colonne obbligatorie mancanti | Bottone disabilitato (silenzioso) | Alert esplicito + errore rosso | MEDIUM | VERIFICATO_IN_CODICE |
| N-02 | PreGenerate | File con 0 righe dati (solo header) | Bottone disabilitato, nessun messaggio | Blocco con messaggio | LOW | INFERITO_DA_ARCHITETTURA |
| N-03 | GeneratedView | Secondo livello revert (ai dati originali dell'import) | Non implementato | Presente (`revertToPreGenerateState()`) | MEDIUM | VERIFICATO_IN_CODICE |
| N-04 | GeneratedView | Snapshot revert riflette stato a inizio sessione, non import originale | `originalData` = dati al load time | N/A | MEDIUM | INFERITO_DA_ARCHITETTURA |
| N-05 | GeneratedView | Nessuna guardia `data.count == editable.count == complete.count` | Crash potenziale se disallineati | N/A | HIGH | VERIFICATO_IN_CODICE |
| N-06 | GeneratedView | Nessuna guardia sync parallela in InventorySyncService | Race condition potenziale | N/A | MEDIUM | VERIFICATO_IN_CODICE |
| N-07 | Database | ProductPrice non eliminato a cascade quando Product viene cancellato | Orfani accumulati | N/A | LOW | VERIFICATO_IN_CODICE |
| N-08 | Database | Nessuna funzione reset/clear database | Non implementato | Non implementato | LOW | VERIFICATO_IN_CODICE |
| N-09 | Database | Barcode duplicati nello stesso file import non validati | Silenzioso | Warning esplicito in ImportAnalysis | LOW | VERIFICATO_IN_CODICE |
| N-10 | Scanner | Camera non disponibile: nessun feedback all'utente | Schermo vuoto | N/A | LOW | VERIFICATO_IN_CODICE |
| N-11 | Startup | `backfillIfNeeded()` chiamato sincrono al lancio | Freeze UI potenziale su DB grande | N/A | MEDIUM | VERIFICATO_IN_CODICE |
| N-12 | HistoryEntry | Deserializzazione JSON corrotta ritorna `[]` silenziosamente | Perdita dati invisibile all'utente | N/A | MEDIUM | VERIFICATO_IN_CODICE |
| N-13 | History | Ricerca per titolo nella lista history | Non implementata | Non implementata | LOW | VERIFICATO_IN_CODICE |
| N-14 | Import | Drag & drop file dal Files.app | Non implementato | N/A (Android) | LOW | VERIFICATO_IN_CODICE |
| N-15 | Export | Nome file XLSX derivato da titolo inventario | Non verificato | Sì (timestamp) | LOW | DA_VALIDARE_MANUALMENTE |

---

#### 1.3 — Funzionalità iOS-specifiche superiori ad Android

| Feature | File | Stato | Valore per l'utente |
|---------|------|-------|---------------------|
| Mark All Complete per righe | GeneratedView | ✅ DONE | iOS > Android (Android manca) |
| Search navigation next/prev | GeneratedView SearchPanel | ✅ DONE | iOS > Android |
| ProductPriceHistoryView | ProductPriceHistoryView.swift | ✅ DONE | iOS > Android |
| EntryInfoEditor (edit metadata) | EntryInfoEditor.swift | ✅ (non tracciato) | iOS > Android |
| PriceFormatting utility | PriceFormatting.swift | ✅ | Coerenza UI |
| LocalizationManager con fallback | LocalizationManager.swift | ✅ | Più robusto di Android |
| Filtri data avanzati History | HistoryView | ✅ DONE | Parity + custom range |

---

#### 1.4 — Confronto UX per flusso operativo (sintesi)

**Import file**: iOS ha blocco esplicito su secondo file in caricamento; Android no. Progress bar presente su entrambi. Drag & drop assente su iOS.

**PreGenerate**: validazione colonne obbligatorie silenziosa su iOS vs alert esplicito Android. Titolo inventario editabile su iOS (EntryInfoEditor), non su Android.

**GeneratedView**: iOS superiore su Mark All Complete, search navigation. Revert iOS parziale (1 livello). Manual entry dialog equivalente.

**Import Analysis**: error export equivalente. Inline editing: iOS via sheet, Android via form inline. Progress su import grande: Android ha chunked %; iOS non ha (TASK-011).

**Database**: CRUD, import/export multi-sheet equivalenti. Barcode dup warning: Android esplicito, iOS silenzioso.

**History**: filtri data equivalenti (iOS li ha, TASK-007 DONE — il report Android era errato). Delete/rename: entrambi funzionanti. Export XLSX: equivalente.

---

### ─── PARTE 2 — AUDIT ARCHITETTURALE E TECNICO ───

| ID | File / Area | Tipo | Descrizione | Impatto reale | Urgenza | Confidenza |
|----|------------|------|-------------|---------------|---------|------------|
| DT-01 | GeneratedView.swift (~3200+ righe) | Dimensioni | File molto grande, cresce con ManualEntrySheet | Rischio regressioni su modifiche future | BASSA | VERIFICATO_IN_CODICE |
| DT-02 | ExcelSessionViewModel.swift (~2260 righe) | Dimensioni + Responsabilità | Viewmodel + ExcelAnalyzer struct insieme | Difficoltà manutenzione | BASSA | VERIFICATO_IN_CODICE |
| DT-03 | DatabaseView + ProductImportViewModel | Duplicazione logica | Logica import prodotti duplicata | Divergenza bug nel tempo | BASSA | VERIFICATO_IN_CODICE |
| DT-04 | InventorySyncService.swift | Race condition | Nessuna guardia contro sync parallele | Raro ma potenzialmente corruttivo | MEDIA | VERIFICATO_IN_CODICE |
| DT-05 | ContentView.swift | Startup sincrono | `backfillIfNeeded()` su main thread al lancio | UX degradata al primo avvio post-migrazione su DB grande | MEDIA | VERIFICATO_IN_CODICE |
| DT-06 | GeneratedView.swift | Coerenza array | Nessuna guardia `data==editable==complete count` | Crash o corruzione silenziosa | MEDIA-ALTA | VERIFICATO_IN_CODICE |
| DT-07 | HistoryEntry.swift | Silent failure | JSON corrotto → `[] ` senza log né alert | Perdita dati invisibile | MEDIA | VERIFICATO_IN_CODICE |
| DT-08 | Models.swift — ProductPrice | Cascade delete | SwiftData senza `.cascade` su `priceHistory` | Orfani accumulati nel DB | BASSA | VERIFICATO_IN_CODICE |
| DT-09 | Models.swift — Product | Timestamp assenti | `Product` senza `createdAt`/`updatedAt` | Audit trail limitato | BASSA | VERIFICATO_IN_CODICE |
| DT-10 | ExcelSessionViewModel | Header duplicati | Colonna duplicata sovrascrive mapping silenziosamente | Edge case; comportamento indefinito | BASSA | VERIFICATO_IN_CODICE |

**Aree architetturalmente solide**: modello SwiftData 5 modelli puliti, localizzazione con fallback, parsing numerico virgola→punto consistente, alias dict multilingua per header, autosave in GeneratedView.

---

### ─── PARTE 3 — AUDIT ROBUSTEZZA ED EDGE CASE ───

| Area | Edge case | Stato iOS | Rischio | Confidenza |
|------|-----------|-----------|---------|------------|
| File grandi | OOM su import molto grandi | Nessun limite codificato | ALTO | VERIFICATO_IN_CODICE |
| Header duplicati | Sovrascrittura silenziosa mapping | Non gestito | BASSO | VERIFICATO_IN_CODICE |
| File 0 righe | Bottone disabilitato, nessun messaggio | UX carente | BASSO | INFERITO_DA_ARCHITETTURA |
| Barcode duplicati griglia | ManualEntrySheet avvisa (CA-5 TASK-008) | Gestito | — | VERIFICATO_IN_CODICE |
| Barcode duplicati DB import | Silenzioso | BASSO | VERIFICATO_IN_CODICE |
| Prezzi nil/zero | Gestiti con `Double?`; zero backfillato | OK | — | VERIFICATO_IN_CODICE |
| Quantità non numeriche | Bloccate in ManualEntrySheet; `?? 0` in SyncService | OK | — | VERIFICATO_IN_CODICE |
| Barcode sporchi | Nessuna validazione formato/lunghezza | BASSO | VERIFICATO_IN_CODICE |
| Export valori numerici | Esportati come stringhe (non numeri Excel) | Incompatibilità potenziale con Excel europeo | BASSO | VERIFICATO_IN_CODICE |
| Import multi-sheet interrotto | Chunked apply → DB in stato parziale coerente | Accettabile | — | INFERITO_DA_ARCHITETTURA |
| Import foglio Products mancante | Probabile errore durante parsing | DA_VALIDARE_MANUALMENTE | BASSO | DA_VALIDARE_MANUALMENTE |
| ProductPrice orfani su delete | Accumulano nel DB | BASSO | VERIFICATO_IN_CODICE |
| Sync parallele | Race condition potenziale | MEDIO (raro) | VERIFICATO_IN_CODICE |
| Backfill al lancio | Blocco main thread su DB grande | MEDIO | VERIFICATO_IN_CODICE |
| HistoryEntry JSON corrotto | Dati persi silenziosamente | MEDIO | VERIFICATO_IN_CODICE |
| Camera non disponibile | Schermo vuoto senza messaggio | BASSO | VERIFICATO_IN_CODICE |

---

### ─── PARTE 4 — SCHEDE OPERATIVE NUOVI TASK ───

---

#### TASK-017 — PreGenerate: validazione esplicita colonne obbligatorie

| Campo | Valore |
|-------|--------|
| **Source gap** | N-01 (+ N-02 opzionalmente incorporabile) |
| **Tipo** | Parity gap + UX safety |
| **Priorità** | MEDIUM |
| **Stato** | TODO |
| **Dipende da** | Nessuno |
| **Nota migrazione** | Nessuna |
| **Evidenza principale** | `PreGenerateView.swift`: `canGenerate` disabilita il bottone "Genera" senza mostrare alcun messaggio quando mancano colonne obbligatorie; comportamento verificato nel codice (N-01, VERIFICATO_IN_CODICE) |

**Scopo**: Mostrare un messaggio di errore esplicito, non solo disabilitare il bottone "Genera", quando le colonne obbligatorie (barcode, productName, purchasePrice) mancano dal file importato. Equivale al comportamento Android (Alert + errore rosso).

**Include**: Messaggio inline in PreGenerateView legato a `canGenerate`. Opzionalmente: messaggio per file con 0 righe dati (N-02, se ritenuto utile).

**Non include**: Modifica alla logica di mapping colonne; validazione su appendRows; refactor di ExcelSessionViewModel.

**File coinvolti**: `PreGenerateView.swift` unicamente.

**Acceptance criteria**:
- CA-1: Quando una o più colonne obbligatorie mancano dall'header rilevato, appare un messaggio inline (sopra o vicino al bottone "Genera") che elenca le colonne assenti.
- CA-2: Il messaggio è visibile subito dopo il caricamento del file (non solo all'attempt di premere "Genera").
- CA-3: Il bottone "Genera" rimane disabilitato — comportamento invariato; il messaggio è aggiuntivo.
- CA-4: Quando tutte le colonne obbligatorie sono presenti, il messaggio non è mostrato.

---

#### TASK-018 — GeneratedView: secondo livello revert (ai dati originali import)

| Campo | Valore |
|-------|--------|
| **Source gap** | N-03, N-04 — GAP-03 parziale da TASK-001 |
| **Tipo** | Parity gap (completa GAP-03) |
| **Priorità** | MEDIUM |
| **Stato** | TODO |
| **Dipende da** | Nessuno (idealmente post-TASK-008 DONE per ridurre conflitti su GeneratedView) |
| **Nota migrazione** | Campo opzionale su HistoryEntry → migrazione SwiftData leggera automatica; entry pre-esistenti avranno `originalDataJSON == nil` (fallback gestibile) |
| **Evidenza principale** | `GeneratedView.swift`: `originalData` viene impostato al load time della sessione corrente, non al momento di `generateHistoryEntry()`; Android ha `revertToPreGenerateState()` su un secondo snapshot (N-03/N-04, VERIFICATO_IN_CODICE + INFERITO_DA_ARCHITETTURA) |

**Scopo**: Implementare un secondo livello di revert in GeneratedView che riporti i dati allo stato dell'import originale (prima di qualsiasi modifica utente, incluse sessioni precedenti autosalvate). Il livello attuale (`originalData`) riflette solo l'inizio della sessione corrente.

**Include**: Nuovo campo `originalDataJSON: Data?` su HistoryEntry, impostato in `generateHistoryEntry()` e mai sovrascritto dall'autosave. Secondo bottone/azione "Ripristina import originale" in GeneratedView, distinto dal revert di livello 1.

**Non include**: Modifica al revert di livello 1 esistente. UI changes fuori da GeneratedView.

**File coinvolti**: `Models.swift` (campo `originalDataJSON`), `ExcelSessionViewModel.swift` (`generateHistoryEntry()`), `GeneratedView.swift` (secondo bottone revert + logica).

**Acceptance criteria**:
- CA-1: Al momento di `generateHistoryEntry()`, `HistoryEntry.originalDataJSON` viene impostato con i dati della griglia dell'import originale e non viene mai modificato da autosave o operazioni successive.
- CA-2: In GeneratedView esiste un secondo bottone/azione revert ("Ripristina import originale") visivamente distinto dal revert di livello 1.
- CA-3: Premendo il secondo revert, la griglia torna ai dati di `originalDataJSON` e viene eseguito autosave; una conferma utente viene richiesta prima dell'operazione (l'azione è irreversibile rispetto alle modifiche correnti).
- CA-4: Se `originalDataJSON == nil` (HistoryEntry creato prima di questo task), il secondo revert non è visibile / è disabilitato con tooltip "Snapshot originale non disponibile".

---

#### TASK-019 — Robustezza: guardie array + cascade delete + async backfill

> **Motivazione raggruppamento**: I tre fix sono indipendenti ma piccoli — troppo piccoli per tre cicli planning/execution separati. Vengono raggruppati per economia operativa. Il rischio differenziato dei sotto-fix è documentato esplicitamente. Il planning distingue i tre sotto-perimetri e i CA sono separati, così Codex può operare su ciascuno in modo isolato.

| Campo | Valore |
|-------|--------|
| **Source gap/debt** | N-05 (Fix A) + N-07, DT-08 (Fix B) + N-11, DT-05 (Fix C) |
| **Tipo** | Bug/rischio + debito tecnico |
| **Priorità** | MEDIUM |
| **Stato** | TODO |
| **Dipende da** | Nessuno |
| **Evidenza principale** | Fix A: `GeneratedView.swift` — nessuna guardia `data.count == editable.count == complete.count` dopo delete/append/revert (N-05, VERIFICATO_IN_CODICE). Fix B: `Models.swift` — `var priceHistory: [ProductPrice]` senza `@Relationship(deleteRule: .cascade)` (DT-08, VERIFICATO_IN_CODICE). Fix C: `ContentView.swift` — `backfillIfNeeded()` chiamato in `.task {}` sul main thread all'avvio (DT-05, VERIFICATO_IN_CODICE) |

**Scopo globale**: Tre fix di robustezza distinti per area ma raggruppati per efficienza.

---

**Fix A — Guardie array disallineati in GeneratedView**

- **Rischio**: MEDIO-ALTO. Un disallineamento tra `data`, `editableValues`, `completeStates` causa comportamento indefinito (crash o corruzionesilenziosamente invisibile all'utente).
- **File**: `GeneratedView.swift` unicamente.
- **Approccio**: Aggiungere guard/assert dopo ogni operazione che modifica gli array (delete, append, revert, init). In caso di disallineamento: log con `debugPrint`, mostrare banner di errore nella griglia, non crashare.
- **Non include**: Tentativo di auto-riparazione degli array; modifica alla logica di business.

  - CA-1A: Dopo ogni operazione che modifica `data`, `editable`, `complete` (delete, append, revert, init), viene verificato che i tre array abbiano la stessa lunghezza.
  - CA-2A: Se il check fallisce, viene emesso `debugPrint("[GeneratedView] ERRORE array disallineati: data=\(x) editable=\(y) complete=\(z)")`.
  - CA-3A: L'UI mostra un banner o messaggio di errore non bloccante (es. "Errore interno: dati non coerenti. Ricarica la sessione.") invece di crashare.

---

**Fix B — Cascade delete ProductPrice su eliminazione Product**

- **Rischio**: BASSO ma rilevante per integrità DB. Il rischio della migrazione SwiftData è basso: `.cascade` su relazione già esistente non altera dati preesistenti né il formato, solo il comportamento al delete.
- **File**: `Models.swift` unicamente.
- **Approccio**: Aggiungere `deleteRule: .cascade` alla relazione `priceHistory` in `Product`. Testare che nessun dato preesistente venga alterato dalla migrazione.
- **Non include**: Modifica a nessun'altra relazione; modifica alla logica di elimiazione prodotti nell'UI.

  - CA-1B: `@Relationship(deleteRule: .cascade)` applicato a `var priceHistory: [ProductPrice]` in `Product`.
  - CA-2B: Quando un `Product` viene eliminato, tutti i `ProductPrice` associati vengono eliminati nella stessa transazione SwiftData.
  - CA-3B: Build compila senza errori; app si avvia correttamente dopo migrazione su dati preesistenti; nessun record `ProductPrice` di altri prodotti viene alterato.

---

**Fix C — Async backfill al lancio dell'app**

- **Rischio**: BASSO. La modifica è puramente al contesto di esecuzione; la logica di backfill non cambia.
- **File**: `ContentView.swift` (e potenzialmente `PriceHistoryBackfillService.swift` solo per adeguamento thread-safety, se necessario).
- **Approccio**: La chiamata a `backfillIfNeeded()` deve uscire dal main thread e non bloccare l'avvio dell'UI. L'implementazione concreta — `Task.detached`, `@ModelActor`, `ModelContainer.mainContext` vs contesto dedicato, o altra strategia compatibile con SwiftData — è lasciata all'execution. Il vincolo obbligatorio è la thread-safety di SwiftData/ModelContext: qualunque soluzione adottata deve garantire che il ModelContext venga usato solo dal thread/actor corretto.
- **Non include**: Modifica alla logica di backfill (quali record vengono creati); modifiche ad altri task al lancio.

  - CA-1C: `backfillIfNeeded()` non è più chiamato sul main thread sincrono; viene eseguito su background task.
  - CA-2C: Al lancio dell'app su DB con 1000+ prodotti, la UI è interattiva immediatamente (nessun freeze visibile).
  - CA-3C: Il backfill produce lo stesso risultato (stessi record inseriti) sia in foreground che in background.

---

#### TASK-020 — Scanner: feedback camera non disponibile

| Campo | Valore |
|-------|--------|
| **Source gap** | N-10 |
| **Tipo** | UX polish + bug percepito |
| **Priorità** | LOW |
| **Stato** | TODO |
| **Dipende da** | Nessuno |
| **Nota migrazione** | Nessuna |
| **Evidenza principale** | `BarcodeScannerView.swift` — nessun branch `else` dopo il controllo su `AVCaptureDevice.default()`; schermo vuoto in caso di camera non disponibile o permesso negato (N-10, VERIFICATO_IN_CODICE) |

**Scopo**: Quando `AVCaptureDevice.default()` fallisce (simulatore, permesso camera negato, hardware assente), `BarcodeScannerView` mostra uno schermo vuoto. Aggiungere un placeholder visivo con messaggio esplicativo.

**Include**: Branch `else` in `BarcodeScannerView` che mostra una view fallback con testo + icona. Se permesso camera negato, bottone "Apri Impostazioni" che chiama `UIApplication.shared.open(settingsURL)`.

**Non include**: Cambio di framework scanner; modifica alla logica di parsing barcode; richiesta proattiva di permesso camera (già gestita da iOS).

**File coinvolti**: `BarcodeScannerView.swift` unicamente.

**Acceptance criteria**:
- CA-1: Quando la camera non è disponibile o il permesso è negato, `BarcodeScannerView` mostra una view fallback con testo descrittivo (es. "Camera non disponibile" o "Permesso camera negato") invece di uno schermo vuoto.
- CA-2: Se il motivo è il permesso negato, è presente un bottone "Apri Impostazioni" che porta l'utente alla pagina permessi iOS dell'app.
- CA-3: Su dispositivo con camera disponibile e permesso concesso, il comportamento è identico all'attuale (nessuna regressione).

---

#### TASK-021 — HistoryEntry: warning su dati corrotti

| Campo | Valore |
|-------|--------|
| **Source gap/debt** | N-12, DT-07 |
| **Tipo** | Robustezza + UX |
| **Priorità** | LOW |
| **Stato** | TODO |
| **Dipende da** | Nessuno |
| **Nota migrazione** | Campo opzionale `isCorrupt: Bool?` su HistoryEntry → migrazione SwiftData leggera automatica; entry preesistenti avranno `nil` (= sano) |
| **Evidenza principale** | `HistoryEntry.swift` — computed property `data`, `editableValues`, `completeStates` usano `(try? JSONDecoder().decode(...)) ?? []`: errore swallowed silenziosamente, nessun log né flag (N-12/DT-07, VERIFICATO_IN_CODICE) |

**Scopo**: Quando la deserializzazione JSON di `dataJSON`, `editableJSON` o `completeJSON` fallisce, l'app ritorna array vuoto silenziosamente. L'utente vede dati vuoti senza spiegazione. Aggiungere logging, un flag di corruzione e feedback visivo.

**Include**: `debugPrint` nei computed property di HistoryEntry in caso di errore. Campo `isCorrupt: Bool?` su `HistoryEntry` (impostato a `true` al fallback). Banner visivo in HistoryView e GeneratedView per entry con `isCorrupt == true`.

**Non include**: Tentativo di recupero dati corrotti. Modifica al formato JSON. Logica di cancellazione automatica delle entry corrotte.

**File coinvolti**: `HistoryEntry.swift` / `Models.swift` (campo `isCorrupt`), `HistoryView.swift` (banner), `GeneratedView.swift` (banner).

**Acceptance criteria**:
- CA-1: Se la deserializzazione di `dataJSON`, `editableJSON` o `completeJSON` lancia un'eccezione, viene emesso `debugPrint("[HistoryEntry <id>] Decodifica fallita: <error>")` oltre al fallback `[]`.
- CA-2: `HistoryEntry` ha un campo `isCorrupt: Bool?`; viene impostato a `true` al primo fallback di deserializzazione.
- CA-3: In HistoryView le entry con `isCorrupt == true` mostrano un'icona o badge distintivo (es. icona di avviso).
- CA-4: Aprire in GeneratedView una entry con `isCorrupt == true` mostra un banner "Dati non leggibili. Questa sessione potrebbe essere corrotta." sopra la griglia invece della griglia vuota silenziosa.

---

### ─── PARTE 5 — MATRICE CONVERSIONE GAP / DEBT → AZIONE ───

> Ogni gap e debito identificato ha un'azione assegnata. Questa tabella è definitiva e impedisce duplicazioni future: se un item compare qui come TASK-NNN, non va mai riaperto come task separato.

#### Gap N-xx

| Gap | Descrizione breve | Azione |
|-----|-------------------|--------|
| N-01 | PreGenerate validation silenziosa | → **TASK-017** |
| N-02 | File 0 righe senza messaggio | → **TASK-017** (opzionalmente incorporabile nella stessa schermata) |
| N-03 | Secondo livello revert | → **TASK-018** |
| N-04 | Snapshot non aggiornato su reopen | → **TASK-018** (incorporato) |
| N-05 | Array GeneratedView disallineati | → **TASK-019 Fix A** |
| N-06 | Race condition sync parallele | → **MONITOR_ONLY** — app single-user; sync parallela architettualmente improbabile; rivalutare se emergono prove reali |
| N-07 | ProductPrice orfani su delete | → **TASK-019 Fix B** |
| N-08 | Nessun reset DB completo | → **WONT_DO** — operazione distruttiva non richiesta; parity Android (anche Android manca) |
| N-09 | Barcode dup non validati in DB import | → **DEFERRED** — low impact; potenzialmente incorporabile in futuro task DB |
| N-10 | Scanner camera senza feedback | → **TASK-020** |
| N-11 | Backfill sincrono al lancio | → **TASK-019 Fix C** |
| N-12 | HistoryEntry JSON corrotto silenzioso | → **TASK-021** |
| N-13 | Ricerca per titolo in History | → **WONT_DO** — Android manca anche; non urgente |
| N-14 | Drag & drop file import | → **DEFERRED** — workaround file picker funziona; bassa priorità; rivalutare su iPad |
| N-15 | Nome file export non verificato | → **DA_VALIDARE_MANUALMENTE** al prossimo test session; non blocca nessun task |

#### Debiti tecnici DT-xx

| DT | Descrizione breve | Azione |
|----|-------------------|--------|
| DT-01 | GeneratedView.swift troppo grande | → **WONT_DO** — refactor con rischio regressioni troppo alto; rinviare a end-of-cycle |
| DT-02 | ExcelSessionViewModel.swift troppo grande | → **WONT_DO** — stessa motivazione |
| DT-03 | Logica import duplicata DatabaseView/ProductImportViewModel | → **TASK-016** (LOW, dopo TASK-005 + TASK-006 DONE) |
| DT-04 | Race condition sync | → **MONITOR_ONLY** — stesso di N-06 |
| DT-05 | Backfill sincrono al lancio | → **TASK-019 Fix C** |
| DT-06 | Array GeneratedView senza guardia | → **TASK-019 Fix A** |
| DT-07 | HistoryEntry silent failure | → **TASK-021** |
| DT-08 | ProductPrice no cascade delete | → **TASK-019 Fix B** |
| DT-09 | Product senza createdAt/updatedAt | → **DEFERRED** — non bloccante; rivalutare se serve audit trail |
| DT-10 | Header duplicati silenziosamente ignorati | → **DEFERRED** — edge case raro; documentare come limitazione nota |

---

### ─── PARTE 6 — OPPORTUNITÀ iOS-SPECIFICHE ───

| Opportunità | Valore pratico | Azione |
|-------------|----------------|--------|
| Validazione colonne con feedback esplicito | ALTO | → TASK-017 |
| Feedback camera non disponibile | MEDIO | → TASK-020 |
| Async backfill al lancio | MEDIO | → TASK-019 Fix C |
| Ricerca per titolo in HistoryView | BASSO-MEDIO | → DEFERRED |
| Drag & drop file | MEDIO (iPad) | → DEFERRED |
| Swipe actions in HistoryView | BASSO | → N/A (EntryInfoEditor già copre) |
| iOS Spotlight / Shortcuts / iCloud | NESSUNO (ora) | → WONT_DO |

---

### ─── PARTE 7 — PRIORITIZZAZIONE FINALE ───

#### Categoria 1 — Da fare adesso (bloccanti o ad alto impatto)

| ID | Titolo | Motivazione |
|----|--------|-------------|
| **TASK-011** | Large import stability + progress UX | Planning completo, pronto per Codex. Sblocca TASK-006. Rischio crash reale. |

#### Categoria 2 — Importanti, prossimo ciclo implementativo

| ID | Titolo | Motivazione |
|----|--------|-------------|
| **TASK-019** | Robustezza array + cascade + async backfill | Tre bug/rischi reali; bassa complessità; Codex può gestirli in sequenza |
| **TASK-017** | PreGenerate column validation | UX safety; effort minimo; elimina punto di confusione frequente |
| **TASK-018** | Secondo livello revert | Completa GAP-03; utile per errori sistematici di import |
| Test manuali TASK-008 | ManualEntrySheet | Review APPROVED; soli test manuali pendenti |
| Test manuali TASK-009 | Backfill service | Review APPROVED; soli test manuali pendenti |
| Test manuali TASK-005 | ImportAnalysis | Review in corso; test manuali sbloccabili subito |

#### Categoria 3 — Low priority, eseguibili in qualsiasi momento

| ID | Titolo | Note |
|----|--------|------|
| **TASK-020** | Scanner camera feedback | Effort minimo |
| **TASK-021** | HistoryEntry corruption warning | Raro in produzione; importante per debug |
| **TASK-015** | Calculate dialog | Unico GAP originale non tracciato; LOW valore operativo |
| **TASK-016** | Deduplication import logic | Dipende da TASK-005 + TASK-006 DONE |

#### Categoria 4 — Non fare ora / mai

| Item | Motivazione |
|------|-------------|
| Refactor GeneratedView/ExcelSessionViewModel | Rischio regressioni alto; beneficio indiretto |
| iOS Spotlight / Shortcuts / iCloud | Prematuro; fuori workflow operativo |
| Drag & drop file | Rinviare; workaround OK |
| Ricerca titolo History | Non urgente; Android manca pure |
| Reset database completo | Operazione distruttiva; non richiesta |

#### Categoria 5 — Dipendono da test manuali utente

| ID | Azione richiesta |
|----|-----------------|
| TASK-005 | Test manuali CA-1..CA-14 → APPROVED o FIX |
| TASK-006 | Dopo TASK-011; poi test manuali CA-13 + dataset grandi |
| TASK-008 | Test manuali T-1..T-28 → conferma DONE |
| TASK-009 | Test manuali VM-1..VM-9 → conferma DONE |
| TASK-010 | Test manuali CA-2, CA-3, CA-6 → conferma DONE |
| TASK-002 | Decisione A (chiudere / investigare / mantenere) |

---

### ─── PARTE 8 — DECISIONI RICHIESTE ALL'UTENTE ───

**Decisione A — Futuro di TASK-002 (External file opening "Apri con")**

| Opzione | Pro | Contro |
|---------|-----|--------|
| a) Chiudere come DONE parziale — "Condividi" funziona; documentare limite "Apri con" | Pulizia backlog; comportamento attuale già utile | Parity Android non raggiunta |
| b) Nuovo task investigazione — open-in-place / document coordination | Potrebbe risolvere | Complessità tecnica alta; comportamento dipende da iOS |
| c) Mantenere BLOCKED indefinitamente | Nessuna perdita di tracking | Non porta a nessun avanzamento |

⭐ Raccomandazione: opzione **a)** — se il workflow reale non richiede "Apri con", la chiusura è la scelta più pulita.

**Decisione B — TASK-015 (Calculate dialog)**
Implementarlo o rimuoverlo dal backlog? È LOW priority; se non serve agli utenti attuali, può essere marcato `WONT_DO`.

**Decisione C — Conferma TASK-017..021**
Confermare l'aggiunta al backlog delle cinque schede presentate nella Parte 4. Se qualcuno non è desiderato, indicarlo per aggiornare la matrice.

**Decisione D — Prossimo task da attivare**
Raccomandazione: **TASK-011** (Large import stability). Planning completo, Codex può partire immediatamente, sblocca TASK-006.

---

**Raccomandazione Claude — riepilogo decisioni (lettura rapida):**
- **A** → Chiudere TASK-002 come DONE parziale: documentare che "Condividi/Invia copia" funziona, "Apri con" cross-app è un limite iOS noto non ulteriormente inseguibile salvo nuova decisione esplicita.
- **B** → TASK-015 (Calculate dialog) non è urgente; se non è richiesto dagli utenti attuali, marcarlo WONT_DO e toglierlo dal backlog attivo.
- **C** → Confermare TASK-017..021 come proposti. Le schede sono operative e i CA sono verificabili.
- **D** → Attivare TASK-011 (Large import stability) come prossimo task. È il più ad alto impatto immediato e sblocca TASK-006.

---

### Rischi residui del planning

| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| DT-06/N-05 (array disallineati): crash latente in GeneratedView | Media | Alto | TASK-019 Fix A affronta il problema |
| DT-07/N-12 (silent data loss HistoryEntry): raro ma grave | Bassa | Alto | TASK-021 aggiunge warning; il dato però è già perso alla manifestazione |
| N-11/DT-05 (backfill lento al lancio) | Bassa-media | Medio | TASK-019 Fix C affronta l'async |
| TASK-006 + TASK-011 accoppiati | Alta | Alto | Prioritizzare TASK-011 immediatamente |
| TASK-019 Fix B (migrazione cascade) | Bassa | Medio | Campo aggiunto a relazione esistente; migrazione SwiftData automatica; testare su device reale |
| TASK-018 (migrazione originalDataJSON) | Bassa | Basso | Campo opzionale; entry preesistenti nil → fallback esplicito |

---

### Handoff → Revisione utente
- **Prossima fase**: REVIEW (da parte dell'utente)
- **Prossimo agente**: UTENTE
- **Azione consigliata**:
  1. Verificare Parte 0 (tracking coerente ✅ confermato)
  2. Leggere Parte 1 (parity audit) — in particolare la nota su GAP-03 e TASK-018
  3. Leggere la matrice Parte 5 — ogni gap/debt ha un'azione assegnata
  4. Rispondere alle Decisioni A, B, C, D (Parte 8)
  5. Confermare o modificare le schede TASK-017..021 (Parte 4)
  6. Scegliere il prossimo task da attivare (Parte 7 Categoria 1)
  7. Dopo conferma → TASK-014 passa a DONE

---

## Execution (Codex)
N/A — Task di solo planning/audit.

---

## Review (Claude)
N/A — La review è implicita nella conferma utente.

---

## Fix (Codex)
N/A

---

## Chiusura

### Conferma utente
- [x] Utente ha confermato il completamento — 2026-03-22

### Decisioni approvate dall'utente (2026-03-22)
- **A**: TASK-002 → chiuso come DONE parziale. "Condividi/Invia copia" funziona; "Apri con" cross-app documentato come limite iOS noto non ulteriormente inseguibile salvo nuova decisione esplicita.
- **B**: TASK-015 (Calculate dialog) → WONT_DO. Non richiesto dagli utenti attuali; GAP-15 archiviato nell'audit.
- **C**: TASK-017..021 → tutte e 5 le schede confermate nel backlog come TODO.
- **D**: Prossimo task da attivare → TASK-011 (Large import stability, memory e progress UX).

### Follow-up residui (non bloccanti)
- Validazione manuale N-15 (nome file export XLSX) alla prossima sessione di test manuale
- Test manuali pendenti: TASK-005, TASK-006 (post-TASK-011), TASK-008, TASK-009, TASK-010

### Riepilogo finale
Audit globale completato. Tracking coerente (3 incoerenze corrette). 17 GAP originali + 15 nuovi gap + 10 debiti tecnici classificati con marker di confidenza. Backlog aggiornato con TASK-017..021 (schede operative complete). Matrice di conversione definitiva. Prioritizzazione in 5 categorie. TASK-002 chiuso, TASK-015 WONT_DO, TASK-011 attivato come prossimo task.

### Data completamento
2026-03-22
