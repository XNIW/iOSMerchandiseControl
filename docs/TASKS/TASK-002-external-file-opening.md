# TASK-002: External file opening (document handoff via CFBundleDocumentTypes)

## Informazioni generali
- **Task ID**: TASK-002
- **Titolo**: External file opening (document handoff via CFBundleDocumentTypes)
- **File task**: `docs/TASKS/TASK-002-external-file-opening.md`
- **Stato**: BLOCKED
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-03-19
- **Ultimo aggiornamento**: 2026-03-19
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Registrare l'app come viewer per file .xlsx, .xls e .html tramite `CFBundleDocumentTypes`, e gestire i file ricevuti da altre app (Files, Mail, Messaggi, etc.) tramite `onOpenURL`, navigando automaticamente a PreGenerateView. Non è una Share Extension — è document handoff.

## Contesto
L'app iOS non appare nel menu "Apri con" di iOS per file Excel o HTML. Gli utenti ricevono file inventario via Mail, Messaggi o Files ma devono aprire manualmente l'app, navigare al file picker e selezionare il file. Su Android questo funziona già tramite intent filters. Identificato come GAP-10 nel gap audit TASK-001.

## Non incluso
- iOS Share Extension (target extension separato con UI nel Share Sheet) — task a parte se necessario
- `LSSupportsOpeningDocumentsInPlace` — valutare in futuro
- Pulizia Documents/Inbox — task dedicato
- Coda URL multipli — policy single-URL, un file alla volta

## File potenzialmente coinvolti
- `iOSMerchandiseControl/Info.plist` (CREARE)
- `iOSMerchandiseControl.xcodeproj/project.pbxproj` (MODIFICARE)
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` (MODIFICARE)
- `iOSMerchandiseControl/ContentView.swift` (MODIFICARE)
- `iOSMerchandiseControl/InventoryHomeView.swift` (MODIFICARE)

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
Se cambiano in corso d'opera, aggiornare QUI prima di proseguire.
- [ ] L'app viene registrata correttamente come viewer per .xlsx, .xls, .html. È selezionabile nei flussi "Apri con" e "Condividi/Invia copia" di Files.app. La disponibilità in app di terze parti dipende da come l'app sorgente implementa il menu di apertura/condivisione.
- [ ] Selezionando l'app, il file viene caricato e si naviga a PreGenerateView
- [ ] Funziona con cold launch (app non in esecuzione)
- [ ] Funziona con app già in foreground
- [ ] Il file picker esistente continua a funzionare invariato
- [ ] File non supportato o invalido aperto da "Apri con": l'app non crasha, mostra errore user-friendly, la sessione non resta in stato incoerente
- [ ] Nessuna nuova dipendenza aggiunta

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Document handoff via CFBundleDocumentTypes + onOpenURL | Share Extension (target separato) | Minimo cambiamento, copre il caso d'uso principale senza nuovo target | attiva |
| 2 | LSHandlerRank = Alternate | Default/Owner | L'app non deve diventare handler predefinito per Excel/HTML | attiva |
| 3 | Policy URL singolo (no coda) | Coda pendingURLs | Semplicità; un file alla volta coerente con flusso file picker | attiva |
| 4 | Validazione tipo file UTType primario + estensione fallback | Solo estensione | Più robusto per file da sandbox con metadata incompleti | attiva |
| 5 | Guard doppio livello (ContentView scarta silenzioso + loadExternalFile errore user-friendly) | Solo guard in loadExternalFile | Evita sovrascrittura pendingOpenURL; secondo livello mostra errore | attiva |
| 6 | LSSupportsOpeningDocumentsInPlace = YES in Info.plist | NO (copia in sandbox — non fa comparire in "Apri con") / Non dichiararlo | YES necessario per "Apri con" in Files.app; l'app legge il file una sola volta e rilascia, security-scoped access già gestito | attiva — aggiornata da NO a YES dopo secondo test manuale |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Analisi
L'app non ha Info.plist fisico né CFBundleDocumentTypes. Il flusso file picker esistente in InventoryHomeView usa `.fileImporter` con `.spreadsheet` e `.html`. Il pattern è: load → showPreGenerate = true → navigazione a PreGenerateView. ExcelSessionViewModel è un ObservableObject passato via environmentObject. Per il document handoff serve: (1) registrazione tipi in Info.plist, (2) handler onOpenURL in ContentView, (3) bridge pendingOpenURL in ExcelSessionViewModel, (4) consumo in InventoryHomeView con validazione e navigazione.

### Approccio proposto
5 file tecnici (1 nuovo, 4 modificati), ~80 righe. Zero dipendenze nuove.

**Step 1 — Creare `iOSMerchandiseControl/Info.plist`**
Info.plist con CFBundleDocumentTypes per 3 UTType: `org.openxmlformats.spreadsheetml.sheet` (xlsx), `com.microsoft.excel.xls` (xls), `public.html` (html+htm). Tutti con LSHandlerRank = Alternate.

**Step 2 — Aggiornare `project.pbxproj`**
Aggiungere `INFOPLIST_FILE = iOSMerchandiseControl/Info.plist;` in Debug e Release. Mantenere `GENERATE_INFOPLIST_FILE = YES` (Xcode merge). Il progetto usa PBXFileSystemSynchronizedRootGroup — Info.plist dovrebbe essere rilevato automaticamente senza PBXFileReference manuale.

**Step 3 — Aggiungere `pendingOpenURL` in `ExcelSessionViewModel.swift`**
`@Published var pendingOpenURL: URL? = nil` dopo lastError. Reset in `resetState()`. Policy URL singolo, nessuna coda. Nota: resetState() è safe perché pendingOpenURL viene consumato (= nil) da InventoryHomeView prima di load().

**Step 4 — Modificare `ContentView.swift`**
Aggiungere `@State private var selectedTab = 0`, `TabView(selection: $selectedTab)`, `.tag()` su ogni tab, `.onOpenURL` con guard `url.isFileURL`, guard `pendingOpenURL == nil && !isLoading` (scarta silenzioso), poi `selectedTab = 0` e `pendingOpenURL = url`.

**Step 5 — Modificare `InventoryHomeView.swift`**
Aggiungere:
- `private static let allowedUTTypes: Set<UTType> = [.spreadsheet, .html]`
- `private static let allowedExtensions: Set<String> = ["xlsx", "xls", "html", "htm"]`
- `isFileTypeSupported(_:)` — URLResourceValues.contentType primario, pathExtension fallback
- `loadExternalFile(_:)` — validazione tipo, guard isLoading, reset nav flags, security scope difensivo, load, showPreGenerate
- `.onChange(of: excelSession.pendingOpenURL)` — warm resume
- `.onAppear` — cold launch

### File da modificare
| File | Azione | Righe stimate |
|------|--------|---------------|
| `iOSMerchandiseControl/Info.plist` | CREARE | ~40 |
| `iOSMerchandiseControl.xcodeproj/project.pbxproj` | MODIFICARE | ~4 |
| `iOSMerchandiseControl/ExcelSessionViewModel.swift` | MODIFICARE | +3 |
| `iOSMerchandiseControl/ContentView.swift` | MODIFICARE | +9 |
| `iOSMerchandiseControl/InventoryHomeView.swift` | MODIFICARE | +38 |

### Rischi identificati
1. **Cold launch timing**: `.onAppear` in InventoryHomeView gestisce il caso in cui `onOpenURL` scatta prima che `onChange` sia registrato
2. **File in Documents/Inbox**: i file si accumulano — non gestito in questo task (follow-up)
3. **Utente già in GeneratedView**: `excelSession.load()` chiama `resetState()` e il NavigationStack si resetta — comportamento coerente con file picker; reset preventivo nav flags in `loadExternalFile` riduce conflitti
4. **Multi-file / URL concorrenti**: policy doppio livello — ContentView scarta silenzioso se pendingOpenURL != nil o isLoading; loadExternalFile blocca con errore user-friendly se isLoading. Nessuna coda
5. **File con tipo non supportato**: validazione esplicita con errore user-friendly
6. **`resetState()` e `pendingOpenURL`**: safe — pendingOpenURL già consumato (= nil) prima di load()

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: Implementare i 5 step nell'ordine indicato. Il piano completo con tutti i code snippet è nel file `~/.claude/plans/playful-roaming-ember.md`. Leggere quel file PRIMA di iniziare. Per ogni step: leggere il file sorgente, applicare le modifiche come descritto nel piano, verificare coerenza. Dopo tutte le modifiche: build check. NON aggiungere dipendenze, NON fare refactor, NON espandere scope.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Registrare l'app come viewer per file `.xlsx`, `.xls` e `.html` tramite `CFBundleDocumentTypes`, intercettare i file aperti da altre app con `onOpenURL`, instradarli al tab Inventario e caricarli nel flusso esistente fino a `PreGenerateView`, seguendo i 5 step del piano senza refactor o dipendenze nuove.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-002-external-file-opening.md`
- `~/.claude/plans/playful-roaming-ember.md`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/InventoryHomeView.swift`
- Verificata assenza iniziale di `iOSMerchandiseControl/Info.plist`

### Piano minimo
1. Creare `iOSMerchandiseControl/Info.plist` con `CFBundleDocumentTypes` per `xlsx`, `xls`, `html`
2. Aggiornare `project.pbxproj` con `INFOPLIST_FILE` in Debug e Release
3. Aggiungere `pendingOpenURL` in `ExcelSessionViewModel` e resettarlo in `resetState()`
4. Aggiornare `ContentView` con `selectedTab`, `.tag()` e `.onOpenURL`
5. Aggiornare `InventoryHomeView` con validazione tipo file, caricamento URL esterno, `.onChange` e `.onAppear`
6. Eseguire build check e riallineare i file di tracking per handoff a review

### Modifiche fatte
- Creato `iOSMerchandiseControl/Info.plist` con tre `CFBundleDocumentTypes`: `org.openxmlformats.spreadsheetml.sheet`, `com.microsoft.excel.xls`, `public.html`, tutti con `CFBundleTypeRole = Viewer` e `LSHandlerRank = Alternate`
- Aggiornato `iOSMerchandiseControl.xcodeproj/project.pbxproj` aggiungendo `INFOPLIST_FILE = iOSMerchandiseControl/Info.plist;` in Debug e Release
- Aggiunto `@Published var pendingOpenURL: URL? = nil` in `ExcelSessionViewModel` e reset del valore in `resetState()`
- Modificato `ContentView` con `@State private var selectedTab = 0`, `TabView(selection:)`, `.tag(0...3)` e `.onOpenURL` con doppio guard (`isFileURL` + `pendingOpenURL == nil && !isLoading`)
- Modificato `InventoryHomeView` aggiungendo `allowedUTTypes`, `allowedExtensions`, `isFileTypeSupported(_:)`, `loadExternalFile(_:)`, consumo di `pendingOpenURL` in `.onChange` e `.onAppear`
- Aggiunta esclusione minima nel `PBXFileSystemSynchronizedRootGroup` del `project.pbxproj` per evitare che `Info.plist` venisse copiato anche nelle risorse: senza questa eccezione il build falliva con `Multiple commands produce .../Info.plist`

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS' -derivedDataPath /tmp/iOSMerchandiseControl-DerivedData -clonedSourcePackagesDirPath /tmp/iOSMerchandiseControl-SourcePackages CODE_SIGNING_ALLOWED=NO build` → `BUILD SUCCEEDED`
- [x] Nessun warning nuovo: ✅ ESEGUITO — esito negativo: il build segnala un warning nuovo di Xcode (`The application supports opening files, but doesn't declare whether it supports opening them in place`) legato a `LSSupportsOpeningDocumentsInPlace` / `UISupportsDocumentBrowser`, lasciato fuori scope come da planning
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — implementati i 5 step richiesti nell'ordine previsto; unica aggiunta minima extra: eccezione nel `PBXFileSystemSynchronizedRootGroup` necessaria per rendere compilabile `Info.plist`
- [ ] Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE — build e wiring verificati, ma i criteri runtime (`Apri con`, cold launch, warm resume, file non supportati/corrotti) richiedono test manuale su device reale non eseguibile in questo ambiente

### Rischi rimasti
- Il build ora compila, ma resta un warning Xcode relativo alla mancata dichiarazione esplicita di `LSSupportsOpeningDocumentsInPlace` / `UISupportsDocumentBrowser`; non è stato corretto perché il planning esclude esplicitamente questo punto dallo scope
- I flussi `Apri con`/Quick Look, cold launch e warm resume non sono ancora verificati manualmente su device reale
- Follow-up candidate fuori scope già noto: cleanup dei file in `Documents/Inbox`

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i 5 step implementati contro il planning, controllare l'eccezione aggiunta nel `PBXFileSystemSynchronizedRootGroup`, confermare il build `xcodebuild` riuscito e validare su device reale i flussi `Apri con` (cold launch, warm resume, file non supportati/corrotti, continuità del file picker)

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Verifica step-by-step contro il planning

| Step | Descrizione | Conforme | Note |
|------|-------------|----------|------|
| 1 | Info.plist con 3 CFBundleDocumentTypes (xlsx, xls, html), Viewer, Alternate | ✅ | Identico al piano |
| 2 | INFOPLIST_FILE in Debug (riga 453) e Release (riga 501) di project.pbxproj | ✅ | GENERATE_INFOPLIST_FILE = YES mantenuto |
| 3 | pendingOpenURL dopo lastError (riga 47) + reset in resetState() (riga 106) | ✅ | Posizionamento e semantica corretti |
| 4 | ContentView: selectedTab, tag(0-3), onOpenURL con doppio guard (isFileURL + pendingOpenURL/isLoading) | ✅ | Implementazione fedele al piano |
| 5 | InventoryHomeView: allowedUTTypes, allowedExtensions, isFileTypeSupported, loadExternalFile, onChange, onAppear | ✅ | Tutti gli elementi presenti e corretti |

### Deviazione dal planning

**PBXFileSystemSynchronizedBuildFileExceptionSet** (righe 66-74 di project.pbxproj): Codex ha aggiunto una `membershipExceptions` per `Info.plist` nel `PBXFileSystemSynchronizedRootGroup`. Il planning diceva "probabilmente non serve aggiungere PBXFileReference" ma non anticipava che il synchronized group avrebbe causato un conflitto "Multiple commands produce Info.plist". La fix è:
- **Necessaria**: senza di essa il build fallisce
- **Minima**: solo una exception declaration, nessun cambio strutturale
- **Corretta**: è il meccanismo standard di Xcode per escludere un file dalla copia risorse quando è già usato come Info.plist del target
- **Non è scope creep**: è un adattamento tecnico necessario per far funzionare lo Step 2

Valutazione: **deviazione accettabile**, ben documentata da Codex nella sezione Execution.

### Problemi critici
- **L'app NON compare in "Apri con" di Files.app** — compare solo nel Share Sheet ("Condividi" / "Invia copia"). Test manuale su device reale conferma che il flusso "Apri con" mostra "Non sono disponibili app". Causa: mancanza di `LSSupportsOpeningDocumentsInPlace` in Info.plist. Senza questa chiave, iOS registra l'app per la condivisione ma non per l'apertura diretta dei documenti. Il warning Xcode segnalava esattamente questo: `The application supports opening files, but doesn't declare whether it supports opening them in place`.

### Problemi medi
Nessuno.

### Miglioramenti opzionali
Nessuno.

### Fix richiesti
- [x] Aggiungere `LSSupportsOpeningDocumentsInPlace` con valore `NO` (boolean false) in `iOSMerchandiseControl/Info.plist` — **FATTO in fase FIX**

### Verifica criteri di accettazione

| Criterio | Verificabile in review? | Stato |
|----------|------------------------|-------|
| Registrazione viewer per .xlsx, .xls, .html | ✅ Sì (Info.plist ispezionato) | Soddisfatto — 3 CFBundleDocumentTypes corretti |
| File caricato → PreGenerateView | ⚠️ Parziale (code path verificato, non testato runtime) | Code path corretto: loadExternalFile → load → showPreGenerate = true |
| Cold launch | ⚠️ Parziale (code path verificato) | .onAppear consuma pendingOpenURL — logica corretta |
| Warm resume | ⚠️ Parziale (code path verificato) | .onChange consuma pendingOpenURL — logica corretta |
| File picker invariato | ✅ Sì (codice confrontato) | .fileImporter non toccato (righe 171-200) |
| Errore user-friendly per file non supportato/invalido | ⚠️ Parziale (code path verificato) | isFileTypeSupported + guard isLoading + alert esistente |
| Nessuna nuova dipendenza | ✅ Sì | Nessun import nuovo, nessun package aggiunto |

I criteri runtime (cold launch, warm resume, file corrotto) richiedono test manuale su device reale — non eseguibili in questo ambiente. Il wiring del codice è corretto e coerente.

### Esito

Esito: **CHANGES_REQUIRED**

Motivazione:
- I 5 step del planning sono stati implementati correttamente
- Ma il test manuale su device reale ha rivelato che l'app **non compare in "Apri con"** — solo nel Share Sheet
- Il criterio di accettazione "l'app viene registrata correttamente come viewer ed è selezionabile nei flussi di apertura file" NON è soddisfatto per il flusso "Apri con"
- La causa è la mancanza di `LSSupportsOpeningDocumentsInPlace` — una chiave che il planning aveva escluso dallo scope, ma che si è rivelata necessaria per soddisfare il criterio di accettazione
- La fix è minimale (2 righe XML in Info.plist) e resta dentro lo scope del task
- Il warning Xcode lo segnalava già durante il build — era un segnale che avremmo dovuto interpretare

### Handoff → Fix
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: Aggiungere in `iOSMerchandiseControl/Info.plist`, dentro il `<dict>` principale (allo stesso livello di `CFBundleDocumentTypes`), le seguenti 2 righe XML:
```xml
<key>LSSupportsOpeningDocumentsInPlace</key>
<false/>
```
Posizionamento: subito dopo la chiusura di `</array>` di CFBundleDocumentTypes e prima di `</dict>` finale. Nessuna altra modifica. Dopo la fix: build check.

### Handoff → nuovo Planning (se REJECTED)
N/A.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Fix applicati
- [x] Aggiunto `LSSupportsOpeningDocumentsInPlace = NO` in `iOSMerchandiseControl/Info.plist`
- [x] Nessun'altra modifica applicata: `CFBundleDocumentTypes`, `CFBundleTypeRole = Viewer`, `LSHandlerRank = Alternate`, UTType e `project.pbxproj` lasciati invariati perché già coerenti con il task
- [x] FIX #2 — Nessuna modifica ulteriore applicata. Su richiesta esplicita dell'utente è stata riesaminata la proposta `NO -> YES` prima di eseguirla
- [x] Conclusione FIX #2: **non** cambiato `LSSupportsOpeningDocumentsInPlace` a `YES` perché la limitazione residua è riportata solo per alcune app di terze parti e `YES` introdurrebbe semantica open-in-place dell'originale. In base alla documentazione Apple, l'open-in-place richiede coordinazione file (`UIDocument` oppure `NSFileCoordinator`/`NSFilePresenter`), che l'app attuale non implementa
- [x] TASK-002 messo in `BLOCKED` su richiesta utente per evitare uno stato finale ambiguo in `REVIEW`
- [x] Motivazione del blocco registrata: il flusso `Condividi / Invia copia` funziona, ma il flusso `Apri con` non e` affidabilmente disponibile per file `.xlsx` da alcune app di terze parti; le fix minime tentate su `Info.plist` non hanno chiuso il criterio di accettazione in modo verificabile e il comportamento residuo sembra dipendere anche dall'app sorgente / dal flusso esposto da iOS

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: ❌ NON ESEGUITO — in FIX #2 non sono state applicate modifiche al codice/plist; per richiesta esplicita il build non è stato rilanciato. Ultimo build valido resta quello di FIX #1 (`BUILD SUCCEEDED`)
- [x] Fix coerenti con review: ✅ ESEGUITO — review e note manuali FIX #2 sono state riesaminate, ma la proposta `NO -> YES` è stata fermata perché non giustificata come fix minima coerente con l'architettura corrente e con i requisiti Apple per open-in-place
- [ ] Criteri di accettazione ancora soddisfatti: ⚠️ NON ESEGUIBILE — l'app è attesa nei flussi Files.app; per alcune app di terze parti la disponibilità dipende dal menu/integrazione scelti dall'app sorgente. Serve ritest manuale mirato su matrice di app sorgenti e flussi (`Apri con` vs `Condividi/Invia copia`)
- [x] Criteri parzialmente soddisfatti: ✅ ESEGUITO — il document handoff di base e il flusso `Condividi / Invia copia` risultano funzionanti; il wiring app-side per import, cold/warm launch e navigazione a `PreGenerateView` resta implementato
- [ ] Criterio ancora non chiuso: ⚠️ NON ESEGUIBILE — disponibilita` affidabile del flusso `Apri con` per `.xlsx` da alcune app di terze parti non verificabile come soddisfatta con l'assetto corrente

### Handoff → Review finale
- **Prossima fase**: BLOCKED
- **Prossimo agente**: —
- **Azione consigliata**: Nessuna ulteriore execution ora. Alla ripresa, rivalutare scope e contratto del task: distinguere esplicitamente tra document handoff supportato nei flussi Files/system e vero supporto `Apri con` cross-app. Follow-up candidate proposto: task dedicato per analizzare/documentare la differenza tra supporto document handoff attuale e supporto `Apri con` cross-app, decidendo se limitare il criterio ai flussi supportati dal sistema o pianificare un'implementazione completa di open-in-place/coordinazione file

---

## Review finale post-fix #1 (Claude)

### Verifica fix #1
- `LSSupportsOpeningDocumentsInPlace = <false/>` presente in Info.plist — applicata correttamente
- Build: `BUILD SUCCEEDED`, warning risolto
- Nessun scope creep

### Esito review #1: APPROVED (condizionato a test manuali)

### Test manuale #1 — FALLITO
L'utente ha ritestato su device reale: l'app compare in "Condividi/Invia copia" ma **NON in "Apri con"**.

**Analisi causa root**: `LSSupportsOpeningDocumentsInPlace = NO` dice a iOS "l'app riceve copie di file" ma non la qualifica per il flusso "Apri con", che è semanticamente diverso: implica "apri questo documento nell'app". iOS riserva "Apri con" alle app che dichiarano `YES` (capacità di aprire file in-place) o che usano `UISupportsDocumentBrowser`/`DocumentGroup`.

**Opzioni valutate**:
1. `LSSupportsOpeningDocumentsInPlace = YES` — l'app accede al file nella posizione originale via security-scoped URL. Il codice gestisce già `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()`. L'app legge il file una sola volta e rilascia. **Fix minimale, compatibile con l'architettura attuale.**
2. `UISupportsDocumentBrowser = YES` — incompatibile: forza un document browser come schermata iniziale, incompatibile con il TabView. Richiederebbe conversione a DocumentGroup. Fuori scope.
3. Aggiornare criterio e accettare limitazione — rinuncia al flusso "Apri con".

**Decisione**: Opzione 1 — cambiare da `NO` a `YES`. L'impatto sul codice è nullo (security-scoped access già gestito). L'unica differenza operativa: con `YES`, i file da "Apri con" NON vengono copiati in Documents/Inbox ma restano nella posizione originale.

**Criterio di accettazione aggiornato**: Riformulato per riflettere che la disponibilità in app di terze parti dipende dalla loro implementazione del menu, non solo dalla nostra configurazione.

---

## Review → FIX #2 (Claude)

### Esito: CHANGES_REQUIRED

### Fix richiesti
- [ ] In `iOSMerchandiseControl/Info.plist`, cambiare `<false/>` in `<true/>` alla riga 46 (valore di `LSSupportsOpeningDocumentsInPlace`)

### Handoff → Fix #2
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: In `iOSMerchandiseControl/Info.plist`, cambiare il valore di `LSSupportsOpeningDocumentsInPlace` da `<false/>` a `<true/>`. È una modifica di 1 riga. Nessun'altra modifica. Dopo la fix: build check.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- Pulizia Documents/Inbox — cleanup periodico (rilevante solo per file ricevuti via Share Sheet; con "Apri con" + `LSSupportsOpeningDocumentsInPlace = YES` i file non vengono copiati)
- iOS Share Extension — target separato se richiesto

### Riepilogo finale
[Cosa è stato fatto, limiti noti, note per il futuro]

### Data completamento
YYYY-MM-DD
