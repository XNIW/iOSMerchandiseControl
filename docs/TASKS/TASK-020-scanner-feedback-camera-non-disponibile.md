# TASK-020: Scanner — feedback camera non disponibile

## Informazioni generali
- **Task ID**: TASK-020
- **Titolo**: Scanner: feedback camera non disponibile
- **File task**: `docs/TASKS/TASK-020-scanner-feedback-camera-non-disponibile.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW *(sospesa — task non attivo progetto; review tecnica **APPROVED**; **nessun fix richiesto**; test manuali **T-1..T-6 non eseguiti** in questo turno; task **non** DONE)*
- **Responsabile attuale**: UTENTE *(test manuali T-1..T-6; se regressioni → **FIX** / CODEX → **REVIEW** finale → conferma utente → DONE)*
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 (**user override / tracking**) — review **APPROVED**; test manuali **non eseguiti**; **non** DONE; sospeso; focus progetto su **TASK-021**.
- **Ultimo agente che ha operato**: CLAUDE *(tracking post-review + sospensione)*

## Dipendenze
- **Dipende da**: nessuno (TASK-014 gap N-10).
- **Sblocca**: chiusura percepita del gap «schermo vuoto» scanner su simulatore / permesso negato / hardware assente / fallimento sessione.

## Scopo
Introdurre una **macchina a stati esplicita** senza ambiguità tra «permesso/device OK» e «sessione AV in esecuzione»: **`ScannerView`** gestisce stato UI (fallback, header, overlay solo quando la sessione è realmente operativa); **`BarcodeScannerView`** incapsula **solo** pipeline AV (configurazione su **coda serial dedicata**, preview, metadata) e notifica esiti **`onSessionReady`** / **`sessionSetupFailed`** al genitore. Refactor **minimo**: niente `ObservableObject` / ViewModel dedicato salvo necessità documentata.

## Contesto
Origine: **TASK-014** (gap **N-10**). Stato attuale (`BarcodeScannerView.swift`): se `AVCaptureDevice.default(for: .video)` o `canAddInput` / `canAddOutput` falliscono, `makeUIView` ritorna una `CameraPreviewView` senza sessione → **preview nera**; non c’è uso di `AVCaptureDevice.authorizationStatus` nella shell SwiftUI. **`ScannerView`** (stesso file) incolla `BarcodeScannerView` a tutto schermo con overlay e header, senza sapere se la camera è utilizzabile.

## Non incluso
- Cambio di framework di scansione, tipi di codice supportati, o logica di parsing nel `Coordinator`.
- Richiesta permesso **ripetuta in loop** o flussi che forzino dialog di sistema oltre a quanto necessario per il primo accesso (vedi rischi).
- Localizzazione di **`NSCameraUsageDescription`** via `InfoPlist.strings` (resta policy TASK-010: stringa di sistema; eventuale migrazione = task separato).
- Modifiche a schermate che **non** presentano `ScannerView` (DatabaseView / GeneratedView restano consumer della sheet esistente).
- **Nuovo** `ObservableObject` / ViewModel dedicato allo scanner per questo task (preferenza: enum + `@State` + view private — vedi Planning § Refactor).

## File coinvolti (definitivi)
| File | Ruolo |
|------|--------|
| `iOSMerchandiseControl/BarcodeScannerView.swift` | **`ScannerView`**: enum stato locale + `@State`; `ScannerFallbackView` **private**; rivalutazione auth su foreground; montaggio `BarcodeScannerView` quando prerequisiti **sessione tentabile**; overlay solo in **`ready`**. **`BarcodeScannerView`**: `AVCaptureSession` posseduta dal **`Coordinator`**; setup/teardown su **`sessionQueue`**; callback **`onSessionReady`** / **`sessionSetupFailed`** **one-shot** / idempotenti. |
| `iOSMerchandiseControl/it.lproj/Localizable.strings` | Nuove chiavi messaggi fallback / bottone impostazioni (e titoli se necessari). |
| `iOSMerchandiseControl/en.lproj/Localizable.strings` | Idem. |
| `iOSMerchandiseControl/es.lproj/Localizable.strings` | Idem. |
| `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` | Idem. |
| `iOSMerchandiseControl.xcodeproj/project.pbxproj` | **Verifica** (non modifica attesa): presenza `INFOPLIST_KEY_NSCameraUsageDescription` — vedi Planning § Permessi. |
| `iOSMerchandiseControl/Info.plist` | **Verifica**: oggi **non** contiene la chiave camera; la stringa è generata da build settings Xcode. Documentare in Execution l’esito della verifica. |

## Criteri di accettazione
- [ ] **CA-SIM**: Su **simulatore iOS** (nessuna camera reale o `AVCaptureDevice.default(for: .video)` nil dopo flusso auth coerente), aprendo `ScannerView` non compare uno schermo vuoto/nero a pieno schermo: compare il fallback **`cameraUnavailable`** con messaggio localizzato comprensibile; **nessun** bottone «Apri impostazioni» (non applicabile).
- [ ] **CA-DENIED**: Su **device** con **permesso camera negato** (`.denied`), il fallback **`permissionDenied`** mostra messaggio dedicato + bottone **«Apri impostazioni»** che apre le impostazioni dell’app (URL impostazioni app).
- [ ] **CA-RESTRICTED**: Con autorizzazione **`.restricted`**, messaggio fallback dedicato (distinto o condiviso con copy “accesso limitato” — a scelta minima Codex). Il bottone **«Apri impostazioni»** è **opzionale**: se non presente, documentare in Execution; **non** è condizione bloccante per la review se il caso non è riproducibile (**⚠️ NON ESEGUIBILE** con motivo). Obiettivo: nessun blocco del task su dettaglio poco testabile.
- [ ] **CA-UNAVAILABLE**: Con autorizzazione **autorizzata** ma **nessun device video** (caso tipico simulatore / hardware assente), stato **`cameraUnavailable`** e messaggio distinto da `sessionSetupFailed` dove possibile.
- [ ] **CA-SESSION-FAIL**: Con permesso OK e device presente, se la configurazione sessione fallisce (`canAddInput` / `canAddOutput` / `startRunning` o equivalente documentato in Execution), stato **`sessionSetupFailed`**: fallback con messaggio **generico** chiaro (no stack trace utente); header con chiusura ancora funzionante.
- [ ] **CA-HAPPY**: Stato **`ready`** (sessione avviata con successo, vedi stato **`startingSession` → `ready`**): comportamento attuale **invariato** per anteprima, overlay `ScannerOverlay`, lettura codice, **feedback** sonoro/tattile, **`onCodeScanned`** + **`dismiss()`** della sheet come oggi.
- [ ] **CA-STARTING**: Durante **`startingSession`**, l’area sotto header non è uno schermo nero muto: placeholder non vuoto (es. `ProgressView` / indicatore leggero) fino a `onSessionReady` o fallimento.
- [ ] **CA-DISMISS**: In **ogni** stato (inclusi fallback e `startingSession`), il bottone **chiudi** (X) in header continua a chiudere la sheet senza hang né crash.
- [ ] **CA-NO-LOOP**: Nessun ciclo di richiesta permesso: al massimo **una** richiesta coerente quando lo stato è `.notDetermined` (transitorio); dopo risposta utente si passa a `permissionDenied` / flusso sessione / ecc. senza ri-aprire dialog inutilmente a ogni render.
- [ ] **CA-LOC**: Tutte le stringhe **nuove** visibili all’utente passano da **`L("…")`** con voci in **tutte** le lingue del progetto (`it`, `en`, `es`, `zh-Hans`).
- [ ] **CA-THREAD**: Configurazione `AVCaptureSession` e chiamate **`startRunning()`** / **`stopRunning()`** avvengono su **coda serial dedicata** (`sessionQueue`), non sul main thread; aggiornamenti di stato UI verso SwiftUI su main (documentare in Execution).
- [ ] **CA-SETTINGS-RETURN**: Con **sheet scanner ancora aperta**, al ritorno dell’app in foreground dopo modifica permesso in Impostazioni, **`ScannerView` rivaluta** `authorizationStatus` (senza nuovo `requestAccess` se già determinato) così da poter passare a **`startingSession` / `ready`** **senza** obbligare l’utente a chiudere e riaprire la sheet. Se l’implementazione sceglie solo la riapertura sheet come UX accettata, documentarlo esplicitamente in Execution (scelta consigliata: refresh su foreground).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap da TASK-014 senza planning tecnico completo | Planning completo immediato | Attivazione backlog | **superata** (#11) |
| 11 | Stati UX includono **`startingSession`** tra «prerequisiti OK» e **`ready`** (sessione in esecuzione confermata) | Solo `ready` senza transizione | Elimina chicken-and-egg montaggio vs conferma sessione | attiva |
| 12 | **`ScannerView`** = stato + fallback + header; **`BarcodeScannerView`** = pipeline AV + callback **`onSessionReady` / fallimento**; montata quando **`startingSession` o `ready`** (stessa view; genitore guida stato da callback) | Montaggio solo a `ready` già vero | `ready` si ottiene solo dopo callback; prima si è in `startingSession` | attiva |
| 13 | `ScannerOverlay` visibile **solo** in **`ready`** | Overlay anche in `startingSession` | Evita laser su placeholder | attiva |
| 14 | Verifica **`NSCameraUsageDescription`** su `project.pbxproj` (INFOPLIST_KEY) | Assunzione senza verifica | CA tracciabile | attiva |
| 15 | **`sessionQueue`** serial per tutte le mutazioni sessione + `startRunning`/`stopRunning` | Session setup sul main | UI sheet reattiva; allineamento best practice AVFoundation | attiva |
| 16 | Nessun ViewModel dedicato: enum + `@State` + `ScannerFallbackView` private | ObservableObject per scanner | Refactor minimo | attiva |
| 17 | `.restricted`: bottone Impostazioni **opzionale**; CA non bloccante se assente + non testabile | Parità rigida con denied | Evita blocco review su scenario raro | attiva |
| 18 | **`AVCaptureSession`** posseduta dal **`Coordinator`** (o owner interno lifecycle-stable), **non** variabile locale solo in `makeUIView` | Session creata e persa a ogni passaggio representable | Una sessione per ciclo coordinator; teardown sicuro; meno ricreazioni; transizioni `startingSession` → `ready` e chiusura sheet stabili | attiva |
| 19 | **`onSessionReady`** / segnalazione **`sessionSetupFailed`**: **one-shot / idempotenti** per singolo ciclo di vita sessione (una sola transizione esito utile) | Callback ripetuti a ogni `updateUIView` | No doppi aggiornamenti stato SwiftUI; race con teardown ridotte | attiva |
| 20 | Con sheet scanner aperta e stato **`startingSession`/`ready`**, a **`.inactive`/`.background`**: **`stopRunning()`** deterministico su **`sessionQueue`**; a **`.active`**: rivalutare auth+device e riprendere con **stessa sessione/Coordinator** tramite **`startRunning()`** senza teardown completo (salvo fallimento o smontaggio) | Lasciare sessione attiva in background o stato UI ambiguo | Risparmio batteria; comportamento minimo; niente doppi `onSessionReady` se già `ready` | attiva |

---

## Planning (Claude)

### Obiettivo
Eliminare schermo nero/vuoto e il **chicken-and-egg** «montare solo a `ready` vs `ready` solo dopo setup»: separare chiaramente **prerequisito sessione tentabile**, **avvio sessione in corso**, **sessione operativa**, **fallimento**.

### Modello stati — flusso univoco (senza ambiguità)
Un solo enum locale in `ScannerView` (nome a discrezione Codex, es. `ScannerScreenState`), con almeno questi casi:

| Stato | Ruolo |
|-------|--------|
| **`authorizing`** | Transitorio: `authorizationStatus == .notDetermined`; al massimo una `requestAccess`; UI leggera (es. `ProgressView`). |
| **`permissionDenied`** | `.denied` → fallback + bottone Impostazioni (**obbligatorio**). |
| **`restricted`** | `.restricted` → fallback; messaggio dedicato; bottone Impostazioni **opzionale** (Decisione 17). |
| **`cameraUnavailable`** | Es. `.authorized` e nessun `AVCaptureDevice` utilizzabile per `.video` — **prima** di tentare sessione; nessun `BarcodeScannerView` montato. |
| **`startingSession`** | `.authorized` **e** device non nil: prerequisiti per tentare AV. **`BarcodeScannerView` è montata**. Configurazione + `startRunning` avvengono su **`sessionQueue`**; UI sotto header = placeholder non nero (CA-STARTING) finché non arriva **`onSessionReady`** o errore. |
| **`ready`** | Callback **`onSessionReady`** dopo sessione avviata con successo: preview visibile; mostrare `ScannerOverlay`; stesso comportamento scansione/dismiss dell’implementazione attuale. |
| **`sessionSetupFailed`** | Callback da `BarcodeScannerView` se setup/`startRunning` fallisce: **smontare** (o non mostrare) pipeline fallita; mostrare `ScannerFallbackView` con messaggio generico. |

**Diagramma logico (testo):**
```
authorizing → (dopo risposta utente) → permissionDenied | restricted | cameraUnavailable
         → authorized + no device → cameraUnavailable
         → authorized + device     → startingSession → onSessionReady → ready
                                                ↘ failure → sessionSetupFailed
```

**Regola:** **`ready`** non è impostato dal solo controllo auth/device: richiede sempre **`onSessionReady`** dal layer AV. **`startingSession`** è l’unico stato in cui si monta `BarcodeScannerView` per il percorso felice (insieme a `ready` è la **stessa** istanza del ciclo di vita — il genitore aggiorna solo stato UI da callback; oppure transizione `startingSession` → `ready` senza smontare la view).

### Threading AVFoundation (obbligatorio in execution)
- Introdurre una **coda serial dedicata** (es. `private let sessionQueue = DispatchQueue(label: "…BarcodeScanner…")`) nel `Coordinator` (o tipo che possiede la sessione).
- Su **`sessionQueue`** eseguire: `beginConfiguration` / `addInput` / `addOutput` / `commitConfiguration`, **`startRunning()`**, **`stopRunning()`**, e ogni altra mutazione della `AVCaptureSession`.
- **Mai** chiamare `startRunning`/`stopRunning` dal main thread (rischio freeze UI con sessioni reali).
- Dopo esito (successo/fallimento), pubblicare aggiornamenti verso SwiftUI con `DispatchQueue.main.async` (callback verso `ScannerView` / aggiornamento stato).
- **`updateUIView` / `dismantleUIView`**: coordinare `stopRunning` e cleanup su **`sessionQueue`**; evitare deadlock (pattern documentato Apple: async su sessionQueue, attendere fine se necessario con meccanismo sicuro — Codex documenta scelta in Execution).

### Ownership della sessione (`AVCaptureSession`)
- L’istanza **`AVCaptureSession`** non deve essere una **variabile locale** creata e abbandonata dentro **`makeUIView`** (o equivalente) senza owner stabile.
- Deve essere **posseduta** dal **`Coordinator`** di `BarcodeScannerView` (o da un **tipo interno equivalente** con lo **stesso lifecycle** del `Coordinator` — es. proprietà `let`/`var` del coordinator creata una volta per `makeCoordinator` / vita del representable).
- Obiettivi:
  - **Evitare ricreazioni inutili** della sessione a ogni invocazione del lifecycle SwiftUI.
  - **Centralizzare** configurazione, `startRunning`, `stopRunning` e teardown nello stesso owner che conosce `sessionQueue`.
  - Rendere **`dismantleUIView`** **deterministico**: stop/cleanup verso la **stessa** sessione nota, senza riferimenti persi.
  - Ridurre implementazioni **fragili** nelle transizioni **`startingSession` → `ready`** (stesso coordinator/sessione) e alla **chiusura sheet** (teardown ordinato).

### Callback `onSessionReady` / `sessionSetupFailed` — one-shot / idempotenti
- **`onSessionReady`** e la notifica di fallimento verso **`sessionSetupFailed`** devono essere emessi al **più una volta** per ogni **tentativo di ciclo di vita sessione** rilevante (success **oppure** failure esclusivi).
- Implementazione attesa (indicativa): flag interni tipo `didEmitSessionOutcome` / `hasReportedSetupResult` nel `Coordinator`, resettati solo quando si inizia un **nuovo** setup esplicito (o nuovo coordinator), così che:
  - ripetute chiamate a **`updateUIView`**, re-render SwiftUI o micro-cicli del representable **non** invochino di nuovo le callback verso il genitore;
  - non si verifichino **doppie transizioni** di stato (`startingSession` → `ready` due volte, o success dopo failure);
  - si riducano **race** tra esito e **teardown** (callback già consumate prima di stop concorrenti — documentare in Execution se serve ordinamento esplicito).
- Obiettivo: UI **`ScannerView`** aggiornata **una sola volta** per esito, senza duplicati dovuti al lifecycle SwiftUI.

### Cambio scena (`scenePhase`) — policy lifecycle AV
*(Complementare a CA-SETTINGS-RETURN; sheet scanner **ancora presente**.)*

**Sospensione (`.inactive` o `.background`)**  
- Se la sheet scanner è aperta e lo stato **`ScannerView` è `startingSession` o `ready`**, la pipeline AV non deve restare con sessione in esecuzione in background: su **`sessionQueue`** invocare **`stopRunning()`** in modo **deterministico** (ordine rispetto ad altri lavori sulla coda documentato in Execution).  
- Non avviare nuovi `beginConfiguration`/setup in questa fase; limitarsi a stop sicuro della sessione già posseduta dal **`Coordinator`**.

**Ritorno `.active`**  
- **`ScannerView`** **ricalcola** `authorizationStatus` e presenza **device** (stessa logica del flusso iniziale), **senza** nuovo `requestAccess` se lo stato auth non è `notDetermined`.  
- In base al risultato: mostrare il **fallback** appropriato (`permissionDenied`, `restricted`, `cameraUnavailable`, …) oppure ripristinare il percorso **`startingSession` → … → `ready`**.

**Resume: stessa sessione vs teardown (preferenza planning)**  
- **Preferenza esplicita — comportamento minimale e deterministico:** **nessun teardown completo** della `AVCaptureSession` al solo cambio scena finché il `UIViewRepresentable` resta montato e la sheet è la stessa. **Stesso `Coordinator`**, **stessa** istanza sessione.  
- Dopo `.active`, se auth+device sono ancora OK: su **`sessionQueue`** eseguire di nuovo **`startRunning()`** sulla **sessione esistente** (input/output già configurati salvo invalidazione reale).  
- Se **`ScannerView` era già `ready`** prima del background: restare in **`ready`** dopo `startRunning` riuscito; **non** emettere di nuovo **`onSessionReady`** (i callback one-shot restano validi per il ciclo di montaggio corrente — Decisione 19).  
- Se **`ScannerView` era `startingSession`** e non era ancora arrivato `onSessionReady` prima del background: al resume completare avvio; **`onSessionReady`** può ancora scattare **una volta** quando il primo `startRunning` di successo conclude (flag one-shot non già consumato).  
- Se `startRunning` al resume **fallisce** o auth/device non sono più OK: transizione a **`sessionSetupFailed`** o fallback permessi/device; in Execution documentare transizione esatta.  
- **Smontaggio sheet / `dismantleUIView`**: resta l’unico punto di **teardown** completo ordinato (stop + release) già pianificato — non duplicato dalla sola `scenePhase`.

### Architettura — dove vive la logica
1. **`ScannerView`**: enum + `@State`; `ScannerFallbackView` **private** nello stesso file; nessun ViewModel dedicato (Decisione 16).  
   - Monta **`BarcodeScannerView`** quando lo stato è **`startingSession`** o **`ready`** (flusso: entrata in `startingSession` al soddisfare auth+device; transizione a `ready` su `onSessionReady`).  
   - In **`permissionDenied` / `restricted` / `cameraUnavailable` / `sessionSetupFailed`**: solo fallback + header.  
   - **`ScannerOverlay`**: solo se **`ready`**.  
   - **`scenePhase`**: `@Environment(\.scenePhase)` + `onChange` — **sospensione** `.inactive`/`.background`, **rivalutazione** a `.active`, **resume** su stessa sessione come in § **Cambio scena (`scenePhase`)**; include anche il caso **Impostazioni** / permesso (CA-SETTINGS-RETURN) nello stesso handler di `.active`.

2. **`BarcodeScannerView`**: non gestisce fallback testuale; espone parametri minimi es. `onSessionReady: () -> Void`, `onSessionSetupFailed: () -> Void` (o `Binding` equivalente — **minimo** necessario). Esegue tutto il lavoro pesante su **`sessionQueue`**. **`AVCaptureSession`** è proprietà del **`Coordinator`** (o tipo interno con lo **stesso lifecycle**); callback verso il genitore **one-shot / idempotenti** (§ sopra).

### UX per stato
| Stato | Area sotto header | Bottone «Apri impostazioni» |
|-------|-------------------|----------------------------|
| **permissionDenied** | `ScannerFallbackView` | **Sì** |
| **restricted** | `ScannerFallbackView` | Opzionale |
| **cameraUnavailable** | `ScannerFallbackView` | **No** |
| **sessionSetupFailed** | `ScannerFallbackView` | **No** |
| **startingSession** | Preview host + indicatore caricamento (non nero muto) | N/A |
| **ready** | Preview + `ScannerOverlay` | N/A |
| **authorizing** | Placeholder leggero | N/A |

### Refactor — vincoli minimi
- **Vietato** introdurre `ObservableObject` / ViewModel dedicato per questo task salvo blocco tecnico documentato in Execution e assenza di alternativa locale.
- **Preferito**: enum `ScannerScreenState` (o nome equivalente) file-private o nested; `@State` in `ScannerView`; `ScannerFallbackView` `private struct` nello stesso file `BarcodeScannerView.swift`.

### File da modificare (dettaglio operativo)
- **`BarcodeScannerView.swift`**: `sessionQueue`; **`AVCaptureSession`** nel **`Coordinator`** (ownership stabile); refactor `makeUIView` / `Coordinator`; callback `onSessionReady` / `onSessionSetupFailed` **one-shot**; `dismantleUIView` coerente con stop su coda serial; gestione **`scenePhase`** in **`ScannerView`** (stop deterministico background + resume § Cambio scena).
- **Localizable.strings** ×4: chiavi fallback, eventuale stringa “avvio…” per `startingSession` se serve.
- **`project.pbxproj`**: verifica `INFOPLIST_KEY_NSCameraUsageDescription` (come prima).

### Verifica permessi (esito documentale atteso)
- **Trovato** in `iOSMerchandiseControl.xcodeproj/project.pbxproj`: `INFOPLIST_KEY_NSCameraUsageDescription = "Uso la camera per scansionare i codici a barre dei prodotti.";` (verificare Debug/Release in Execution).  
- **Conclusione planning**: **nessuna modifica obbligatoria** se confermato; se mancante in un target, aggiungere.

### Matrice test manuale (passo-passo)
| # | Ambiente | Passi | Esito atteso |
|---|----------|-------|----------------|
| T-1 | **Simulatore** | Aprire sheet scanner | `cameraUnavailable` o `authorizing` → `cameraUnavailable`; mai schermo nero pieno |
| T-2 | **Device — permesso negato** | Disattivare camera per app; aprire scanner | `permissionDenied` + Impostazioni |
| T-3 | **Device — sheet ancora aperta** | Con sheet aperta su denied, andare in Impostazioni, abilitare camera, tornare all’app | **CA-SETTINGS-RETURN**: stato si aggiorna verso `startingSession`/`ready` senza obbligo di chiudere sheet (se implementato); altrimenti Execution documenta alternativa |
| T-4 | **Device — dopo negato** | Chiudere sheet, riaprire scanner | `startingSession` breve → `ready`, scan OK |
| T-5 | **Device — happy path** | Permesso OK; aprire scanner; leggere codice | `ready`; dismiss + feedback come oggi |
| T-6 | **Chiusura** | Tap X in ogni stato | Dismiss sempre |

*(**sessionSetupFailed**: se non riproducibile, ⚠️ in Execution.)*

### Rischi e edge case
| Rischio | Mitigazione |
|---------|-------------|
| Chicken-and-egg ready vs montaggio | Stati **`startingSession`** / **`ready`** + callback espliciti (Decisioni 11–12) |
| Freeze UI su `startRunning` | **`sessionQueue`** (Decisione 15, CA-THREAD) |
| Header illeggibile | Contrasto su fallback / materiale semi-trasparente |
| Loop permessi | Una sola `requestAccess` per ciclo `notDetermined` |
| Dismiss / scan regressione | Contratto `onCodeScanned` + `dismantleUIView` con stop su `sessionQueue` |
| Overlay su errore | Solo in **`ready`** |
| `.restricted` non testabile | Bottone opzionale; CA-RESTRICTED non bloccante (Decisione 17) |
| Session locale in `makeUIView` / callback duplicate | Ownership su **Coordinator** (Decisione 18); callback **one-shot** (Decisione 19) |
| Sessione AV attiva in background / stato UI incoerente al resume | **`stopRunning`** su `sessionQueue` a `.inactive`/`.background`; resume § Cambio scena (Decisione 20) |

### Handoff → Execution (CODEX)
- **Prossima fase**: **EXECUTION**  
- **Prossimo agente**: **CODEX**  
- **Azione consigliata** (ordine):  
  1. Leggere questo file (flusso stati **`authorizing` → … → `startingSession` → `ready` / `sessionSetupFailed`**, § Threading, CA-SETTINGS-RETURN).  
  2. Implementare enum + `@State` + **`ScannerFallbackView`** private in **`ScannerView`**; `scenePhase` per rivalutazione auth a foreground.  
  3. Refactor **`BarcodeScannerView`** / **`Coordinator`**: **`sessionQueue`** per config + `startRunning`/`stopRunning`; callback **`onSessionReady`** e **`onSessionSetupFailed`** (o binding minimo).  
  4. Montare representable per **`startingSession`** e **`ready`**; overlay solo **`ready`**; placeholder in **`startingSession`**.  
  5. Localizzazione ×4; verifica **INFOPLIST_KEY**; build; **Execution** con check ✅/⚠️/❌ e **Handoff post-execution** → **REVIEW (CLAUDE)**.

---

## Execution (Codex)
### Obiettivo compreso
Eseguire il planning di TASK-020 con il minimo cambiamento necessario: `ScannerView` proprietaria dello stato UI/fallback, `BarcodeScannerView` limitata alla pipeline AV, `AVCaptureSession` posseduta dal `Coordinator`, `sessionQueue` seriale per setup/start/stop, refresh su `scenePhase`, stringhe nuove solo via `L(...)`.

### Tracking preliminare
- Verificata coerenza iniziale tra `docs/MASTER-PLAN.md` e questo file: `TASK-020` era gia' `ACTIVE / EXECUTION / CODEX`; nessun riallineamento minimo necessario prima del codice.
- Verificato path del task attivo coerente con il filesystem.
- Verificata presenza di `INFOPLIST_KEY_NSCameraUsageDescription = "Uso la camera per scansionare i codici a barre dei prodotti."` in `iOSMerchandiseControl.xcodeproj/project.pbxproj` per Debug e Release.
- Verificato che `iOSMerchandiseControl/Info.plist` non contiene direttamente la chiave camera: la stringa resta generata dai build settings Xcode come previsto dal planning. Nessuna modifica necessaria a `project.pbxproj` / `Info.plist`.

### File modificati
- `iOSMerchandiseControl/BarcodeScannerView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Modifiche fatte
- Introdotto enum locale `ScannerScreenState` in `ScannerView` con stati `authorizing`, `permissionDenied`, `restricted`, `cameraUnavailable`, `startingSession`, `ready`, `sessionSetupFailed`.
- Separata la UX per stato: fallback dedicato, bottone Impostazioni solo in `permissionDenied`, overlay rosso solo in `ready`, placeholder non vuoto in `authorizing` / `startingSession`.
- Refactor minimo di `BarcodeScannerView`: `AVCaptureSession` ora posseduta dal `Coordinator`; configurazione, `startRunning()`, `stopRunning()` e teardown passano da `sessionQueue` seriale.
- Aggiunti callback `onSessionReady` / `onSessionSetupFailed` verso il genitore e lifecycle coerente con `scenePhase`: stop deterministico quando la scena non e' attiva e rivalutazione auth/device al ritorno in foreground senza nuovo `requestAccess` se lo stato e' gia' determinato.
- Mantenuto il comportamento happy path esistente per preview, lettura barcode, feedback sonoro/tattile e dismiss della sheet dopo scansione.
- Aggiunte le nuove chiavi localizzate nelle 4 lingue del progetto per placeholder, fallback e azione "Apri impostazioni".
- Scelta minima su `.restricted`: nessun bottone Impostazioni; resta solo messaggio dedicato, come consentito dal planning.

### Verifiche / evidenze per criteri di accettazione
- `CA-SIM` — ✅ ESEGUITO (`STATIC`/`BUILD`): con `authorizationStatus == .authorized` e `AVCaptureDevice.default(for: .video) == nil`, `ScannerView` va in `cameraUnavailable` prima di montare `BarcodeScannerView`; il fallback relativo non espone bottone Impostazioni. Build verde.
- `CA-DENIED` — ✅ ESEGUITO (`STATIC`): con `.denied`, `ScannerView` mostra `permissionDenied` e il fallback include bottone `scanner.action.open_settings` che apre `UIApplication.openSettingsURLString`.
- `CA-RESTRICTED` — ✅ ESEGUITO (`STATIC`): con `.restricted`, `ScannerView` mostra messaggio dedicato tramite `scanner.fallback.restricted.message`; bottone Impostazioni omesso per scelta minima documentata.
- `CA-UNAVAILABLE` — ✅ ESEGUITO (`STATIC`): stato `cameraUnavailable` distinto da `sessionSetupFailed`, valutato nel layer SwiftUI prima del tentativo sessione.
- `CA-SESSION-FAIL` — ✅ ESEGUITO (`STATIC`/`BUILD`): il `Coordinator` segnala `onSessionSetupFailed` se falliscono device/input/output o se `startRunning()` non porta la sessione in `isRunning`; `ScannerView` passa a fallback generico con header/chiusura invariati. Build verde.
- `CA-HAPPY` — ✅ ESEGUITO (`STATIC`/`BUILD`): in `ready` restano preview, `ScannerOverlay`, metadata delegate, feedback sonoro/tattile, `onCodeScanned` e `dismiss()` della sheet.
- `CA-STARTING` — ✅ ESEGUITO (`STATIC`/`BUILD`): in `startingSession` la preview host resta montata ma coperta da `ScannerStatusOverlay` con `ProgressView`, quindi l'area sotto header non e' uno schermo nero muto.
- `CA-DISMISS` — ✅ ESEGUITO (`STATIC`): il bottone X vive fuori dallo switch di stato e continua a chiamare `dismiss()` in tutti gli stati.
- `CA-NO-LOOP` — ✅ ESEGUITO (`STATIC`): `didRequestAccess` impedisce richieste ripetute; `requestAccess` parte al massimo una volta quando lo stato e' `.notDetermined`.
- `CA-LOC` — ✅ ESEGUITO (`STATIC`/`BUILD`): tutte le stringhe nuove passano da `L("...")`; chiavi presenti in `it`, `en`, `es`, `zh-Hans`; `CopyStringsFile --validate` passato in build.
- `CA-THREAD` — ✅ ESEGUITO (`STATIC`/`BUILD`): configurazione sessione, `startRunning()`, `stopRunning()` e teardown avvengono su `sessionQueue`; transizioni UI/callback verso SwiftUI tornano sul main thread.
- `CA-SETTINGS-RETURN` — ✅ ESEGUITO (`STATIC`): `ScannerView` osserva `scenePhase`; a `.active` rivaluta auth/device senza nuovo `requestAccess` se gia' determinato, e riporta il flusso a fallback o `startingSession`/`ready` secondo il caso.

### Matrice test manuale
- `T-1` — ❌ NON ESEGUITO (`SIM`): non eseguito in questo turno.
- `T-2` — ❌ NON ESEGUITO (`MANUAL`): non eseguito in questo turno.
- `T-3` — ❌ NON ESEGUITO (`MANUAL`): non eseguito in questo turno.
- `T-4` — ❌ NON ESEGUITO (`MANUAL`): non eseguito in questo turno.
- `T-5` — ❌ NON ESEGUITO (`MANUAL`): non eseguito in questo turno.
- `T-6` — ❌ NON ESEGUITO (`MANUAL`): non eseguito in questo turno.

### Check obbligatori
- `Build compila` — ✅ ESEGUITO: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build` -> `** BUILD SUCCEEDED **`.
- `Nessun warning nuovo introdotto` — ⚠️ NON ESEGUIBILE: la build di questo turno e' verde e non mostra warning riferiti ai file modificati, ma manca una baseline comparativa nello stesso turno per dimostrare formalmente l'assenza assoluta di warning nuovi. Output osservato: warning di destinazione multipla di `xcodebuild` e nota AppIntents non attribuibili a `TASK-020`.
- `Modifiche coerenti con il planning` — ✅ ESEGUITO: implementati stati in `ScannerView`, lifecycle AV nel `Coordinator`, `sessionQueue`, callback `onSessionReady` / `onSessionSetupFailed`, refresh `scenePhase`, overlay solo in `ready`, nessun ViewModel/ObservableObject.
- `Criteri di accettazione verificati` — ✅ ESEGUITO: verifiche statiche sui rami richiesti + build Debug iphonesimulator riuscita; test manuali restano esplicitamente non eseguiti.

### Rischi residui
- La matrice `T-1..T-6` non e' stata eseguita in questo turno: i comportamenti runtime su simulatore/device restano da confermare in review o in validazione manuale successiva.
- Lo scenario `.restricted` e' implementato solo con messaggio dedicato (senza bottone Impostazioni), coerente col planning ma non validato manualmente su dispositivo reale.
- Il fallback `sessionSetupFailed` e' coperto staticamente; manca una riproduzione runtime controllata di un fallimento `AVCaptureSession` reale.

## Handoff post-execution
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare l'implementazione contro i CA di TASK-020, con focus su lifecycle `scenePhase`, `sessionQueue`, callback verso `ScannerView`, scelta minima su `.restricted` e fatto che `T-1..T-6` restano non eseguiti in questo turno.

---

## Review (Claude)

### Esito: **APPROVED**

### Verifica criteri di accettazione
- **CA-SIM** — ✅ STATIC: `cameraUnavailable` quando device nil; fallback senza bottone Impostazioni.
- **CA-DENIED** — ✅ STATIC: stato `permissionDenied`, fallback con bottone `scanner.action.open_settings` → `UIApplication.openSettingsURLString`.
- **CA-RESTRICTED** — ✅ STATIC: stato dedicato, messaggio distinto, bottone Impostazioni omesso (scelta minima documentata in Execution, coerente con Decisione 17).
- **CA-UNAVAILABLE** — ✅ STATIC: stato `cameraUnavailable` distinto da `sessionSetupFailed`, valutato prima di tentare sessione.
- **CA-SESSION-FAIL** — ✅ STATIC/BUILD: `Coordinator` segnala `onSessionSetupFailed` se config/`startRunning` fallisce; `ScannerView` passa a fallback generico; header funzionante.
- **CA-HAPPY** — ✅ STATIC/BUILD: in `ready` restano preview, `ScannerOverlay`, metadata delegate, feedback sonoro/tattile, `onCodeScanned` + `dismiss()`.
- **CA-STARTING** — ✅ STATIC/BUILD: `ScannerStatusOverlay` con `ProgressView` e messaggio localizzato copre l'area sotto header in `startingSession`.
- **CA-DISMISS** — ✅ STATIC: bottone X nel `header` fuori dallo switch di stato; chiama `dismiss()` in ogni stato.
- **CA-NO-LOOP** — ✅ STATIC: `didRequestAccess` impedisce richieste ripetute; `requestAccess` al massimo una volta per `notDetermined`.
- **CA-LOC** — ✅ STATIC/BUILD: 7 nuove chiavi in tutte e 4 le lingue via `L(...)`.
- **CA-THREAD** — ✅ STATIC/BUILD: `sessionQueue` serial; tutte le mutazioni sessione su coda dedicata; callback verso SwiftUI su main.
- **CA-SETTINGS-RETURN** — ✅ STATIC: `scenePhase` `.active` rivaluta auth/device con `preserveOperationalState` senza nuovo `requestAccess`.

### Verifica architettura e decisioni
- **Decisione 11** (`startingSession`): stato transitorio implementato; nessun chicken-and-egg.
- **Decisione 12** (separazione `ScannerView`/`BarcodeScannerView`): confermata; `BarcodeScannerView` = pipeline AV pura.
- **Decisione 13** (overlay solo `ready`): confermata via `showsOverlay`.
- **Decisione 15** (`sessionQueue`): confermata; coda serial dedicata nel Coordinator.
- **Decisione 16** (nessun ViewModel): confermata; enum + `@State` + view private.
- **Decisione 17** (`.restricted` bottone opzionale): confermata; omesso, documentato.
- **Decisione 18** (ownership sessione nel Coordinator): confermata; `private let session = AVCaptureSession()`.
- **Decisione 19** (callback one-shot): confermata; flag `didEmitSessionReady`/`didEmitSetupFailure`.
- **Decisione 20** (`scenePhase` stop/resume): confermata; `shouldRunSession: scenePhase == .active` pilota start/stop reattivamente.

### Check
- Build compila: ✅ `BUILD SUCCEEDED` Debug iphonesimulator.
- Warning nuovi: ✅ Nessuno dai file TASK-020.
- Scope creep: ✅ Nessuno; perimetro file esatto (5 file modificati, 2 verificati senza modifica).
- Coerenza planning: ✅ Ogni punto del planning ha corrispondenza nel codice.
- T-1..T-6: ⚠️ NON ESEGUIBILE — test manuali, richiedono device/simulatore interattivo.

### Problemi trovati
Nessun problema sostanziale. Nessun fix necessario.

### Osservazioni minori (non bloccanti)
- Righe 459-464 di `refreshScannerState`: i rami `preserveOperationalState` sono ridondanti (assegnano lo stesso valore o il default). Funziona correttamente; cleanup cosmetico non richiesto.

### Rischi residui
- Test manuali T-1..T-6 non eseguiti (atteso).
- `.restricted` non validabile a runtime (Decisione 17).
- `sessionSetupFailed` coperto solo staticamente.

### Handoff post-review
- **Prossima fase**: in attesa di conferma utente (APPROVED senza fix)
- **Prossimo agente**: UTENTE
- **Azione consigliata**: test manuali T-1..T-6 quando possibile; se superati → conferma DONE

### Sospensione (BLOCKED) — decisione utente 2026-03-25
Il task **non** è **DONE**: per decisione utente resta **BLOCKED** finché non vengono eseguiti i **test manuali T-1..T-6** (non eseguiti in questo turno). Review tecnica **APPROVED**, **nessun fix richiesto**.  
**Alla ripresa**: eseguire **T-1..T-6**; se emergono regressioni → **FIX** (CODEX) → **REVIEW**; se OK → **REVIEW** finale se necessario → **conferma utente** → **DONE**.  
Il task **non** è più il task attivo del progetto (vedi `docs/MASTER-PLAN.md`).

---

## Fix (Codex)
*(Non applicabile.)*

---

## Chiusura
### Conferma utente
- [ ] Utente ha confermato il completamento *(differita — task **BLOCKED** per test manuali T-1..T-6 pendenti; review **APPROVED**, **non** DONE)*

### Follow-up candidate
[Da compilare se necessario]

### Riepilogo finale
- Execution completata; review **APPROVED**, nessun fix. Chiusura **DONE** subordinata a test manuali **T-1..T-6** e conferma esplicita utente.

### Data completamento
YYYY-MM-DD *(non impostata — task non DONE)*
