# TASK-001: Gap Audit iOS vs Android — Censimento funzionalità mancanti

## Informazioni generali
- **Task ID**: TASK-001
- **Titolo**: Gap Audit iOS vs Android — Censimento funzionalità mancanti
- **File task**: `docs/TASKS/TASK-001-ios-gap-audit.md`
- **Stato**: DONE
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-03-19
- **Ultimo aggiornamento**: 2026-03-19
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: tutti i task implementativi futuri (TASK-002+)

## Scopo
Definire in modo completo e verificabile tutte le funzionalità mancanti su iOS rispetto alla baseline Android, così da creare un backlog ordinato di task implementativi.

## Contesto
L'app iOS è un port dell'app Android MerchandiseControlSplitView. Il flusso principale (import file → pre-generate → generated → sync) è funzionante, ma circa il 20–30% delle funzionalità secondarie presenti su Android manca ancora. Questo task censisce tutti i gap per pianificare l'implementazione in modo ordinato.

## Non incluso
- Implementazione di codice Swift/SwiftUI/SwiftData
- Refactoring del codice esistente
- Modifiche a dipendenze o API
- Lavoro su funzionalità che non esistono nemmeno su Android

## File potenzialmente coinvolti
Questo task è di sola analisi. I file analizzati (non modificati) sono:
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` (~2260 righe)
- `iOSMerchandiseControl/GeneratedView.swift` (~3245 righe)
- `iOSMerchandiseControl/PreGenerateView.swift`
- `iOSMerchandiseControl/DatabaseView.swift` (~980 righe)
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl/InventorySyncService.swift`
- `iOSMerchandiseControl/InventoryXLSXExporter.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/InventoryHomeView.swift`
- `iOSMerchandiseControl/BarcodeScannerView.swift`
- Repo Android: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

## Criteri di accettazione
- [x] Esiste un file task reale creato dal template
- [x] MASTER-PLAN.md è coerente con il task attivo
- [x] La lista dei gap è completa e ordinata
- [x] Ogni gap ha ID, severità e area
- [x] Sono proposti i task futuri separati
- [x] Non è stato modificato codice applicativo

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Task di puro planning/audit, nessun codice | Audit + fix immediato | Separazione netta planning/execution come da workflow | attiva |
| 2 | Usare la repo Android locale come riferimento | Solo documentazione/memoria | Il codice sorgente è la fonte più affidabile | attiva |

---

## Planning (Claude)

### Analisi

**Metodologia**: Esplorazione completa del codice sorgente iOS e Android, con verifica puntuale di 15 funzionalità specifiche nel codice iOS.

**Stato attuale iOS**: Il flusso principale è completo e funzionante:
- Import file (XLSX/XLS/HTML) → PreGenerate (anteprima, selezione colonne, assegnazione ruoli, supplier/category) → Generated (griglia modificabile, scanner, autosave, sync) → Database (CRUD prodotti, import/export, storico prezzi) → History (lista sessioni, filtri base, export XLSX)

**Fonti di verità**:
- iOS: codice sorgente nella working directory corrente
- Android: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

---

### Lista funzionalità mancanti

#### GAP-01 — Append file in PreGenerate
- **Descrizione**: Possibilità di aggiungere righe da un secondo file Excel a dati già caricati in PreGenerate
- **Comportamento attuale iOS**: `ExcelSessionViewModel.load()` chiama `resetState()` prima di caricare — ogni caricamento sovrascrive i dati precedenti. Non esiste UI per append.
- **Comportamento atteso (Android)**: Pulsante "Append File" in PreGenerateScreen. Valida che le colonne del nuovo file siano compatibili, poi aggiunge le righe ai dati esistenti.
- **Severità**: HIGH
- **Area**: PreGenerate
- **Rischio regressione**: Medio — tocca il flusso di caricamento dati che è centrale
- **File iOS coinvolti**: `ExcelSessionViewModel.swift`, `PreGenerateView.swift`
- **Note**: Richiede validazione header compatibilità tra file

#### GAP-02 — Reload file in PreGenerate
- **Descrizione**: Possibilità di scartare i dati correnti e ricaricare un nuovo file senza uscire da PreGenerate
- **Comportamento attuale iOS**: L'utente deve tornare a InventoryHomeView per selezionare un nuovo file
- **Comportamento atteso (Android)**: Pulsante "Reload" in PreGenerateScreen che apre il file picker e ricomincia il caricamento
- **Severità**: MEDIUM
- **Area**: PreGenerate
- **Rischio regressione**: Basso — è un reset + nuovo caricamento
- **File iOS coinvolti**: `PreGenerateView.swift`, `ExcelSessionViewModel.swift`
- **Note**: Implementazione relativamente semplice, reset + nuovo load

#### GAP-03 — Revert/Restore in GeneratedView
- **Descrizione**: Ripristinare i dati della griglia allo stato originale (pre-editing)
- **Comportamento attuale iOS**: Nessuna funzionalità di revert. Le modifiche sono persistite dall'autosave senza possibilità di annullamento globale.
- **Comportamento atteso (Android)**: Due livelli di undo: (1) revert allo stato pre-GeneratedScreen, (2) restore del HistoryEntry ai dati originali sovrascrivendo le modifiche
- **Severità**: HIGH
- **Area**: Generated
- **Rischio regressione**: Medio — richiede salvataggio di uno snapshot dei dati originali
- **File iOS coinvolti**: `GeneratedView.swift`, `ExcelSessionViewModel.swift`, `Models.swift` (HistoryEntry)
- **Note**: Serve un meccanismo di backup dei dati originali al momento della generazione

#### GAP-04 — Mark All Complete in GeneratedView
- **Descrizione**: Pulsante per marcare tutte le righe come completate in un colpo solo
- **Comportamento attuale iOS**: Completamento solo riga per riga (context menu, swipe, o detail panel)
- **Comportamento atteso (Android)**: Pulsante "Mark All Complete" nella toolbar
- **Severità**: MEDIUM
- **Area**: Generated
- **Rischio regressione**: Basso — operazione additiva sulla UI esistente
- **File iOS coinvolti**: `GeneratedView.swift`
- **Note**: Implementazione semplice, iterazione su completeStates

#### GAP-05 — Delete row in GeneratedView
- **Descrizione**: Eliminare una riga dalla griglia inventario
- **Comportamento attuale iOS**: Nessuna funzionalità di eliminazione righe. Le righe possono solo essere marcate complete/incomplete.
- **Comportamento atteso (Android)**: Pulsante/azione per eliminare una riga dalla griglia, rimuovendola da dati, editableValues e completeStates
- **Severità**: MEDIUM
- **Area**: Generated
- **Rischio regressione**: Medio — deve mantenere coerenza tra dataJSON, editableJSON, completeJSON
- **File iOS coinvolti**: `GeneratedView.swift`, `Models.swift` (HistoryEntry)
- **Note**: Attenzione alla sincronizzazione degli indici dopo eliminazione

#### GAP-06 — Error export in ImportAnalysis
- **Descrizione**: Esportare gli errori di import analysis in un file XLSX per correzione esterna
- **Comportamento attuale iOS**: ImportAnalysisView mostra gli errori in una lista read-only, senza opzione di export
- **Comportamento atteso (Android)**: Pulsante "Esporta errori" che genera un file XLSX con le righe in errore e il motivo dell'errore come colonna aggiuntiva
- **Severità**: HIGH
- **Area**: ImportAnalysis
- **Rischio regressione**: Basso — funzionalità aggiuntiva, non modifica il flusso esistente
- **File iOS coinvolti**: `ImportAnalysisView.swift`, `ProductImportViewModel.swift`, nuovo file `ImportErrorExporter.swift` (o integrazione in esistente)
- **Note**: Riutilizzabile per diversi contesti di import (database e inventory)

#### GAP-07 — Full Database Export (multi-sheet)
- **Descrizione**: Export del database completo su XLSX multi-foglio (prodotti, fornitori, categorie, storico prezzi)
- **Comportamento attuale iOS**: `makeProductsXLSX()` esporta solo i prodotti su un singolo foglio con 9 colonne
- **Comportamento atteso (Android)**: Export multi-sheet: Products (tutti i campi inclusi old prices), Suppliers, Categories, PriceHistory
- **Severità**: HIGH
- **Area**: Database
- **Rischio regressione**: Basso — estensione dell'export esistente
- **File iOS coinvolti**: `DatabaseView.swift` (funzione `makeProductsXLSX`)
- **Note**: xlsxwriter supporta già i fogli multipli

#### GAP-08 — Full Database Import (multi-sheet)
- **Descrizione**: Import di un file XLSX multi-foglio per ripristinare/aggiornare il database completo
- **Comportamento attuale iOS**: L'import database accetta solo struttura single-sheet normalizzata a campi Product
- **Comportamento atteso (Android)**: Import multi-sheet che legge Products, Suppliers, Categories, PriceHistory e li merge nel database esistente
- **Severità**: HIGH
- **Area**: Database
- **Rischio regressione**: Alto — operazione distruttiva potenziale sul database
- **File iOS coinvolti**: `DatabaseView.swift`, `ProductImportViewModel.swift`, `ExcelSessionViewModel.swift` (ExcelAnalyzer per parsing multi-sheet)
- **Note**: Dipende da GAP-07 (stesso formato). Serve validazione robusta e conferma utente prima di applicare.

#### GAP-09 — History — Filtri data avanzati
- **Descrizione**: Filtri cronologia con range personalizzato e opzioni aggiuntive
- **Comportamento attuale iOS**: Tre filtri predefiniti: Tutti, Ultimi 7 giorni, Ultimi 30 giorni
- **Comportamento atteso (Android)**: Tutti, Ultimo mese, Mese precedente, Range personalizzato (date picker start/end)
- **Severità**: MEDIUM
- **Area**: History
- **Rischio regressione**: Basso — estensione del filtro esistente
- **File iOS coinvolti**: `HistoryView.swift`
- **Note**: iOS ha DatePicker nativo, implementazione diretta

#### GAP-10 — External file opening / Share from other apps
- **Descrizione**: Registrazione dell'app come handler per file Excel/HTML condivisi da altre app
- **Comportamento attuale iOS**: Nessuna registrazione document types in Info.plist. L'app non appare nel menu "Apri con" o "Condividi" di altre app per file Excel.
- **Comportamento atteso (Android)**: Intent filters per ACTION_SEND, ACTION_SEND_MULTIPLE, ACTION_VIEW con MIME types per Excel e HTML. I file ricevuti vengono automaticamente indirizzati a PreGenerateScreen.
- **Severità**: HIGH
- **Area**: AppIntegration
- **Rischio regressione**: Basso — configurazione Info.plist + gestione URL in entrata
- **File iOS coinvolti**: `Info.plist` (o target settings in Xcode), `iOSMerchandiseControlApp.swift`, `InventoryHomeView.swift`
- **Note**: Su iOS si implementa con CFBundleDocumentTypes + `onOpenURL` o scene delegate

#### GAP-11 — Inline editing in ImportAnalysis
- **Descrizione**: Modifica dei dati dei prodotti nell'anteprima di import analysis prima di applicare
- **Comportamento attuale iOS**: ImportAnalysisView mostra i dati in formato read-only. L'utente può solo applicare o annullare l'intero import.
- **Comportamento atteso (Android)**: I prodotti nuovi e gli aggiornamenti possono essere modificati inline nella schermata di analisi prima della conferma
- **Severità**: MEDIUM
- **Area**: ImportAnalysis
- **Rischio regressione**: Medio — modifica la struttura dati dell'analisi che diventa mutabile
- **File iOS coinvolti**: `ImportAnalysisView.swift`, `ProductImportViewModel.swift`
- **Note**: Richiede che ProductImportAnalysisResult diventi mutabile o che si usi un layer di editing separato

#### GAP-12 — Old price fields su Product model
- **Descrizione**: Campi persistenti oldPurchasePrice / oldRetailPrice sul modello Product
- **Comportamento attuale iOS**: Il modello Product ha solo `purchasePrice` e `retailPrice`. I "vecchi prezzi" sono calcolati temporaneamente in ExcelSessionViewModel durante la pre-generazione, ma non persistiti.
- **Comportamento atteso (Android)**: Product entity ha `oldPurchasePrice` e `oldRetailPrice` come campi persistiti. Quando il prodotto viene aggiornato (sync, import), i vecchi valori vengono salvati prima della sovrascrittura.
- **Severità**: MEDIUM
- **Area**: PriceHistory
- **Rischio regressione**: Medio — modifica allo schema SwiftData, richiede migrazione
- **File iOS coinvolti**: `Models.swift` (Product), `InventorySyncService.swift`, `ProductImportViewModel.swift`
- **Note**: SwiftData gestisce migrazioni leggere automaticamente per campi opzionali aggiunti. Valutare se lo storico prezzi (ProductPrice) rende questo campo ridondante.

#### GAP-13 — Search navigation in GeneratedView (next/previous)
- **Descrizione**: Navigazione tra i risultati di ricerca con pulsanti avanti/indietro
- **Comportamento attuale iOS**: La ricerca mostra una lista di risultati; l'utente può tappare un risultato per saltare alla riga, ma non c'è navigazione sequenziale.
- **Comportamento atteso (Android)**: Ricerca con evidenziazione delle celle corrispondenti, conteggio match, e pulsanti Next/Previous per ciclare tra i risultati
- **Severità**: LOW
- **Area**: Generated
- **Rischio regressione**: Basso — estensione della UI di ricerca esistente
- **File iOS coinvolti**: `GeneratedView.swift` (InventorySearchSheet)
- **Note**: Miglioramento UX, non bloccante

#### GAP-14 — Localizzazione UI completa
- **Descrizione**: Supporto multilingua con file di stringhe localizzate
- **Comportamento attuale iOS**: Tutta la UI è hardcoded in italiano. Esiste un'impostazione lingua in OptionsView ma non ci sono file .strings/.xcstrings. Il cambio lingua non ha effetto.
- **Comportamento atteso (Android)**: String resources per 4 lingue (English, Italiano, Español, 中文). Tutte le stringhe UI sono localizzate. Il cambio lingua applica immediatamente la traduzione.
- **Severità**: MEDIUM
- **Area**: Altro
- **Rischio regressione**: Basso — aggiunta file di risorse, non modifica logica
- **File iOS coinvolti**: Tutti i file SwiftUI (estrazione stringhe), `OptionsView.swift`, creazione Localizable.xcstrings
- **Note**: Task molto ampio come effort. Può essere fatto incrementalmente. L'infrastruttura (impostazione lingua) esiste già.

#### GAP-15 — Calculate dialog in GeneratedView
- **Descrizione**: Dialogo per calcolo prezzi personalizzato nella griglia inventario
- **Comportamento attuale iOS**: Nessun dialogo calcolatrice. Esiste un parser RPN per formule Excel ma è per l'import, non esposto all'utente.
- **Comportamento atteso (Android)**: Dialogo "Calcola" nella toolbar che permette calcoli sui prezzi (es. sconto percentuale, ricarico)
- **Severità**: LOW
- **Area**: Generated
- **Rischio regressione**: Basso — funzionalità aggiuntiva isolata
- **File iOS coinvolti**: `GeneratedView.swift`
- **Note**: Valutare se effettivamente usato dagli utenti prima di implementare

#### GAP-16 — Manual row addition dialog con barcode lookup
- **Descrizione**: Dialogo strutturato per aggiunta manuale righe con ricerca automatica nel database
- **Comportamento attuale iOS**: L'aggiunta manuale di righe è basica (disponibile solo in modalità manuale). Non c'è un dialogo strutturato con lookup automatico dal database quando si scansiona o inserisce un barcode.
- **Comportamento atteso (Android)**: Dialogo con campi (barcode, nome, prezzi, quantità, categoria). Se il barcode esiste nel database, i campi vengono pre-compilati automaticamente. Ricerca prodotto via dropdown.
- **Severità**: MEDIUM
- **Area**: Generated
- **Rischio regressione**: Basso — funzionalità aggiuntiva
- **File iOS coinvolti**: `GeneratedView.swift`
- **Note**: Lo scanner iOS già fa lookup, ma il dialogo manuale è meno strutturato

#### GAP-17 — Price Backfill Worker
- **Descrizione**: Task in background per riempire lo storico prezzi mancante
- **Comportamento attuale iOS**: Nessun meccanismo di backfill. Lo storico prezzi viene creato solo durante operazioni esplicite (edit, import, sync).
- **Comportamento atteso (Android)**: WorkManager job che all'avvio dell'app scansiona i prodotti senza storico prezzi e crea record ProductPrice retroattivi
- **Severità**: LOW
- **Area**: PriceHistory
- **Rischio regressione**: Basso — operazione in background idempotente
- **File iOS coinvolti**: `iOSMerchandiseControlApp.swift`, `Models.swift`
- **Note**: Su iOS si può usare un task al lancio dell'app. Utile solo se ci sono prodotti importati prima dell'introduzione dello storico prezzi.

---

### Classificazione finale

#### 1. Gap critici da fare prima
| ID | Nome | Motivazione priorità |
|----|------|---------------------|
| GAP-10 | External file opening | Bloccante per workflow reale: utenti ricevono Excel via email/messaggi e non possono aprirli direttamente nell'app |
| GAP-03 | Revert/Restore in GeneratedView | Sicurezza dati: senza revert l'utente non può annullare errori di editing massivi |
| GAP-06 | Error export in ImportAnalysis | Bloccante per workflow import: senza export errori, l'utente non può correggere file problematici |
| GAP-01 | Append file in PreGenerate | Alto valore: inventari reali spesso coinvolgono più file da fornitori diversi |

#### 2. Gap ad alto valore ma non bloccanti
| ID | Nome | Motivazione |
|----|------|-------------|
| GAP-07 | Full Database Export (multi-sheet) | Backup completo del database, importante per sicurezza dati |
| GAP-08 | Full Database Import (multi-sheet) | Complementare a GAP-07, restore da backup |
| GAP-05 | Delete row in GeneratedView | Operazione comune durante editing inventario |
| GAP-11 | Inline editing in ImportAnalysis | Migliora significativamente il flusso di import |

#### 3. Gap migliorativi
| ID | Nome | Motivazione |
|----|------|-------------|
| GAP-04 | Mark All Complete | Convenience feature, risparmia tempo |
| GAP-02 | Reload file in PreGenerate | Convenience, workaround esistente (tornare indietro) |
| GAP-09 | History filtri avanzati | UX improvement, filtri base già funzionanti |
| GAP-12 | Old price fields su Product | Potenzialmente ridondante con ProductPrice history |
| GAP-16 | Manual row addition dialog con lookup | Scanner già fa lookup, dialogo è miglioramento UX |
| GAP-14 | Localizzazione UI completa | Ampio effort, app funzionale in italiano |

#### 4. Gap da rinviare eventualmente
| ID | Nome | Motivazione |
|----|------|-------------|
| GAP-13 | Search navigation next/previous | Nice-to-have, ricerca base funziona |
| GAP-15 | Calculate dialog | Uso reale da verificare |
| GAP-17 | Price Backfill Worker | Utile solo in scenari edge |

---

### Proposta backlog — Task futuri

#### TASK-002 — External file opening + share integration
- **Scopo**: Registrare l'app come handler per file Excel/HTML da altre app iOS (Mail, Files, Safari, messaggi)
- **Dipende da**: nessuno
- **Priorità**: CRITICAL
- **Gap coperti**: GAP-10
- **Perché separato**: Configurazione a livello di app (Info.plist, scene delegate), indipendente da UI specifiche

#### TASK-003 — PreGenerate append/reload parity
- **Scopo**: Aggiungere append file (con validazione header) e reload file in PreGenerateView
- **Dipende da**: nessuno
- **Priorità**: HIGH
- **Gap coperti**: GAP-01, GAP-02
- **Perché separato**: Entrambe le funzionalità toccano lo stesso flusso (PreGenerate + ExcelSessionViewModel) e condividono logica

#### TASK-004 — GeneratedView editing parity (revert, delete row, mark all, search nav)
- **Scopo**: Aggiungere revert/restore, eliminazione righe, mark all complete, e navigazione ricerca in GeneratedView
- **Dipende da**: nessuno
- **Priorità**: HIGH
- **Gap coperti**: GAP-03, GAP-04, GAP-05, GAP-13
- **Perché separato**: Tutte modifiche a GeneratedView, possono essere testate insieme. Se troppo grande, scomponibile ulteriormente.

#### TASK-005 — ImportAnalysis error export + inline editing
- **Scopo**: Aggiungere export errori in XLSX e editing inline dei prodotti prima di applicare l'import
- **Dipende da**: nessuno
- **Priorità**: HIGH
- **Gap coperti**: GAP-06, GAP-11
- **Perché separato**: Entrambe le funzionalità migliorano lo stesso flusso ImportAnalysis

#### TASK-006 — Database full import/export (multi-sheet)
- **Scopo**: Estendere export prodotti a multi-sheet XLSX e aggiungere import multi-sheet per backup/restore
- **Dipende da**: nessuno (ma GAP-07 export va fatto prima di GAP-08 import)
- **Priorità**: HIGH
- **Gap coperti**: GAP-07, GAP-08
- **Perché separato**: Funzionalità database autonome, formato condiviso tra import/export

#### TASK-007 — History advanced filters
- **Scopo**: Aggiungere filtro mese corrente, mese precedente, e range personalizzato con date picker
- **Dipende da**: nessuno
- **Priorità**: MEDIUM
- **Gap coperti**: GAP-09
- **Perché separato**: Modifica isolata a HistoryView, basso rischio

#### TASK-008 — Generated manual row dialog + calculate
- **Scopo**: Dialogo strutturato per aggiunta manuale righe con lookup database, e dialogo calcolo prezzi
- **Dipende da**: nessuno
- **Priorità**: MEDIUM
- **Gap coperti**: GAP-15, GAP-16
- **Perché separato**: Funzionalità GeneratedView secondarie, possono essere rimandate

#### TASK-009 — Product model old prices + price backfill
- **Scopo**: Aggiungere campi oldPurchasePrice/oldRetailPrice al modello Product e backfill storico mancante
- **Dipende da**: nessuno
- **Priorità**: LOW
- **Gap coperti**: GAP-12, GAP-17
- **Perché separato**: Modifiche al modello dati, da valutare se effettivamente necessarie dato che ProductPrice history esiste

#### TASK-010 — Localizzazione UI multilingua
- **Scopo**: Estrarre tutte le stringhe UI in Localizable.xcstrings e tradurre in EN, ES, ZH
- **Dipende da**: idealmente dopo la stabilizzazione delle altre feature (per evitare rework stringhe)
- **Priorità**: LOW
- **Gap coperti**: GAP-14
- **Perché separato**: Task trasversale molto ampio, tocca tutti i file, va fatto a fine stabilizzazione

---

### Rischi identificati
1. **GeneratedView.swift è molto grande** (~3245 righe): aggiungere funzionalità (GAP-03, 04, 05, 13) aumenta la complessità. Valutare se scomporre il file prima.
2. **ExcelSessionViewModel.swift è molto grande** (~2260 righe): append file (GAP-01) aggiunge logica a un file già sovraccarico.
3. **Full database import (GAP-08)** è potenzialmente distruttivo: serve UX di conferma robusta e possibilmente backup automatico pre-import.
4. **Migrazione SwiftData (GAP-12)**: aggiunta campi opzionali è gestita automaticamente, ma va testata.
5. **TASK-004 potrebbe essere troppo grande**: se necessario, scomponibile in sotto-task (revert separato da delete row).

### Handoff → Decisione utente
- **Prossima fase**: Il planning/audit è completato. Nessuna execution parte.
- **Prossimo agente**: UTENTE
- **Azione consigliata**: Revisione della lista gap e della proposta backlog. Scegliere il primo task da attivare (suggerito: TASK-002 External file opening, oppure TASK-003 PreGenerate append/reload). Il task corrente (TASK-001) può essere marcato DONE dopo conferma utente.

---

## Execution (Codex)
N/A — Task di solo planning/audit, nessuna execution prevista.

---

## Review (Claude)
N/A — Task di solo planning/audit. La review è implicita nella conferma utente della lista gap.

---

## Fix (Codex)
N/A

---

## Chiusura

### Conferma utente
- [x] Utente ha confermato il completamento

### Follow-up candidate
Nessuno — tutti i gap identificati sono proposti come task futuri nel backlog (TASK-002 … TASK-010).

### Riepilogo finale
Gap audit completato: 17 funzionalità mancanti censite (GAP-01 … GAP-17), classificate per severità e area, raggruppate in 9 task futuri (TASK-002 … TASK-010) nel backlog del MASTER-PLAN. Nessun codice applicativo modificato.

### Data completamento
2026-03-19
