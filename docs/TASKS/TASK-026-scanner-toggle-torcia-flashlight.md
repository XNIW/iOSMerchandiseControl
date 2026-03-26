# TASK-026: Scanner — toggle torcia (flashlight)

## Informazioni generali
- **Task ID**: TASK-026
- **Titolo**: Scanner: toggle torcia (flashlight)
- **File task**: `docs/TASKS/TASK-026-scanner-toggle-torcia-flashlight.md`
- **Stato**: BLOCKED *(sospeso post-review positiva; **non** DONE — **pending manual validation**)*
- **Fase attuale**: — *(task non ACTIVE; review tecnica **APPROVED** acquisita — vedi sezione **Review**)*
- **Responsabile attuale**: — *(nessuno operativo; in attesa **test manuali** **T-1…T-9** prima della chiusura finale)*
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 *(tracking: review **APPROVED**, **nessun fix** aperto; **test manuali non eseguiti**; task **BLOCKED** fino a validazione manuale — vedi **Review** e nota sospensione)*
- **Ultimo agente che ha operato**: CLAUDE *(review positiva + riallineamento tracking)*

## Dipendenze
- **Dipende da**: nessuno (origine: gap audit iOS vs Android 2026-03-25; contesto scanner gia' toccato da **TASK-020** ma nessuna dipenza bloccante formale).
- **Sblocca**: parita' UX funzionale con Android in ambienti scarsamente illuminati; riduce attrito nello scanning barcode.

## Scopo
Aggiungere nello **scanner barcode iOS** un controllo utente per **accendere/spegnere la torcia (flashlight)** della camera posteriore, migliorando la leggibilita' del codice in condizioni di luce bassa, senza introdurre scope oltre al toggle e al ciclo di vita della sessione camera.

## Contesto / problema UX
- Su Android il flusso scanner prevede tipicamente un **toggle torcia**; su iOS oggi l'app usa **`ScannerView`** / **`BarcodeScannerView`** (`AVCaptureDevice`) senza esposizione esplicita della torcia.
- In magazzino / interni poco illuminati l'utente puo' fallire lo scan non per mancanza di permessi ma per **contrasto insufficiente** sul codice.
- **TASK-020** ha gia' migliorato gli stati **camera non disponibile**; questo task e' **ortogonale**: torcia solo quando la camera e' attiva e il device la supporta.

## Non incluso
- Modifiche al parsing barcode, al formato dati, o al database.
- Nuove dipendenze SPM.
- Torcia su **fotocamera frontale** (non pertinente allo scan barcode).
- **Persistenza** della preferenza torcia tra aperture scanner o tra riavvii app (**NO**, fuori scope per TASK-026; vedi tabella Decisioni).
- Allineamento riga-per-riga col codice Kotlin (solo **riferimento funzionale**: presenza toggle e UX attesa).

## File coinvolti (perimetro ottimizzato)
- **Primario (tutto il comportamento torcia)**: `iOSMerchandiseControl/BarcodeScannerView.swift` — `ScannerScreenState`, `ScannerView`, `BarcodeScannerView` + `Coordinator` (`sessionQueue` `iOSMerchandiseControl.BarcodeScanner.session`), `dismantleUIView` → `teardownSession()`.
- **Secondario**: `iOSMerchandiseControl/*.lproj/Localizable.strings` (it, en, es, zh-Hans) — nuove chiavi `scanner.torch.*`.
- **Call site — fonte di verità = comando, non un numero «blindato» nel testo**  
  - Eseguire dal root del repo: `rg '\\bScannerView\\(' --glob '*.swift'` (il `\b` evita il falso positivo su **`BarcodeScannerView(`**).  
  - **Ribadimento**: il **conteggio** e l'**elenco** riportati piu' sotto nel task valgono **solo** come **ultimo esito noto** (memo/documentazione); **non** sono verita' definitiva. L'**unica** fonte di verita' **finale** e' l'output di **`rg '\\bScannerView\\(' --glob '*.swift'`** eseguito sul working tree **dopo** **sync col remoto** (pull/fetch+merge), subito prima dell'execution finale e del merge — il testo del task **non** sostituisce quel comando.  
  - **Obbligo**: **prima** dell'execution finale e **prima** del merge, **ricalcolare** l'output del comando; l'elenco file/occorrenze nel task e' solo **ultimo esito noto** (snapshot locale / ultima revisione), **non** contratto immutabile.  
  - Se l'output **cambia** rispetto allo snapshot qui sotto → aggiornare **questa sezione**, i test **T-2** e **T-9** (elenco ingressi da coprire) e il bullet call site nell'**handoff** nello stesso commit/turno, così il planning non resta stantio.  
  - **Ultimo esito noto** (da aggiornare quando cambia il tree): `GeneratedView.swift` — 3 occorrenze; `DatabaseView.swift` — 1; nessun altro match `\bScannerView(` oltre a questi nel tree verificato (la definizione di `ScannerView` e' in `BarcodeScannerView.swift` e non coincide col pattern di *invocazione*).
- **`BarcodeScannerView`**: verifica separata con `rg 'BarcodeScannerView\\(' --glob '*.swift'` — **ultimo esito noto**: un solo uso, interno nello stesso file (stesso obbligo di ricalcolo prima di merge se il repo diverge).
- **Perimetro esecuzione**: lavoro **quasi interamente** in `BarcodeScannerView.swift`; call site esterni **non** richiedono modifiche salvo cambio firma (non atteso). **Nessuna logica torch** in `GeneratedView` / `DatabaseView`.
- **Info.plist**: nessun nuovo usage string atteso (camera gia' in uso); verifica rapida in execution.

## Criteri di accettazione
- [ ] **CA-1**: Con `screenState == .ready` e device che **supporta** torcia sulla camera usata per lo scan, l'utente puo' **attivare/disattivare** la torcia dal controllo dedicato; **tap rapidi ripetuti** sul toggle: nessun crash, nessun **desync** persistente tra UI (`torchRequestedOn`) e stato reale torcia sul device.
- [ ] **CA-2**: Dopo **scan riuscito** (`metadataOutput` → `onCodeScanned` → dismiss), la torcia e' **OFF immediatamente** (ordine: spegnimento torcia su `sessionQueue` prima o insieme allo stop sessione coerente con implementazione, senza flash residuo perceptibile oltre i limiti di sistema).
- [ ] **CA-3**: **Dismiss manuale** dello scanner (bottone chiudi sheet): torcia **OFF**; **`dismantleUIView` / `teardownSession()`**: torcia **OFF** forzata sul device di cattura prima/durante teardown.
- [ ] **CA-4**: Con `scenePhase` **inactive** o **background**: torcia **OFF** esplicita lato app; al **ritorno foreground** (`scenePhase == .active`) **nessun** ripristino automatico della torcia — `torchRequestedOn` e effetto hardware rimangono / tornano **OFF** (stato UI allineato).
- [ ] **CA-5**: Transizioni verso stati **non operativi** (`permissionDenied`, `restricted`, `cameraUnavailable`, `sessionSetupFailed`, `authorizing`, `startingSession`) o torcia **non** disponibile: **nessun** controllo torcia **interattivo** (nessun bottone torcia disabilitato/morto); l'header puo' mostrare solo lo **slot destro** con **placeholder** non interattivo come da **D-10** (layout stabile). In `.ready` con torch disponibile: toggle interattivo nello slot.
- [ ] **CA-6**: **Riaprendo** lo scanner (nuova presentazione sheet), stato iniziale torcia **sempre OFF** (`torchRequestedOn == false`, hardware spento).
- [ ] **CA-7**: **Nessuna regressione** al flusso scanner condiviso dopo TASK-020: messaggi fallback, permessi, `refreshScannerState` / preservazione stati operativi al foreground restano corretti; build **Debug** senza errori; nessun warning **evitabile** nuovo.
- [ ] **CA-8**: Se `lockForConfiguration` o l'applicazione/spegnimento torcia su `AVCaptureDevice` **fallisce** (eccezione / `false` / stato incoerente): **nessun** alert e **nessun** nuovo stato schermata dedicato; si riallinea a **OFF** lato UI (`torchRequestedOn` via `resetTorchUIState()` o equivalente); il Coordinator forza hardware spento e, se possibile, lo scanner **continua** a funzionare (cattura + scan); toggle e hardware **coerenti** (nessun UI «ON» con torch realmente spenta dopo il recovery).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| D-1 | **Posizione controllo**: nell'**header** di `ScannerView`, **a destra**, **subito prima** del bottone chiusura (`xmark.circle.fill`). | Toolbar separata; overlay flottante sul preview | Allineato all'header gia' presente; discoverability coerente con chiusura. | Approvata |
| D-2 | **Stile**: **solo icona**; SF Symbol **`flashlight.off.fill`** quando torcia richiesta spenta / **`flashlight.on.fill`** quando richiesta accesa. | Testo «Torcia»; simboli generici `bolt` | Parita' visiva con pattern iOS; compatto in header. | Approvata |
| D-3 | **Visibilita'**: mostrare il toggle **solo** quando `screenState == .ready` **e** il device segnala torcia disponibile (`isTorchAvailable == true` dal layer capture). | Sempre visibile disabilitato | Evita bottone morto; coerente con CA-5. | Approvata |
| D-4 | **Fallback**: se torcia **non** disponibile o sessione **non** in stato **ready**, **nessun** controllo torcia **interattivo** (niente bottone disabilitato/morto); il layout resta stabile grazie al **placeholder** di **D-10**. | Toggle disabilitato / visibile ma inutile | UX richiesta + coerenza con slot fisso. | Approvata |
| D-5 | **Stato iniziale** a ogni apertura scanner: **OFF**. | Ripristino ultimo stato | Semplicita' e prevedibilita'; niente sorprese in ambienti luminosi. | Approvata |
| D-6 | **Persistenza** preferenza torcia (UserDefaults / AppStorage): **NO**, fuori scope TASK-026. | Ricordare ultimo stato | Scope creep; eventuale follow-up candidate in chiusura task. | Approvata |
| D-7 | **Area tappabile** del toggle: minimo **44×44 pt** (HIG), anche se l'icona e' piu' piccola (`contentShape` / frame minimo). | Icona piccola senza hit target | Target usabile in campo / con guanti leggeri. | Approvata |
| D-8 | **Gerarchia e coerenza visiva (vincolante)**: il toggle resta nella **stessa famiglia** del bottone chiusura gia' presente (`xmark.circle.fill`) — stesso trattamento cromatico (bianco / opacita' analoga), stessa scala tipografica dell'icona (`title2` o equivalente gia' usato nel close), **senza** background colorati, **senza** capsule, **senza** stile «toolbar custom» o badge: controllo **plain**, compatto, sobrio, sul **header nero** esistente; deve sembrare **nativo dell'UI attuale**, non una feature incollata dopo. | Chip colorati; Material extra; stile diverso dal close | Continuita' con TASK-020 / header scanner; riduce rumore visivo. | Approvata |
| D-9 | **Animazioni**: nessuna animazione **superflua** sul toggle (niente spring/bounce dedicati); transizioni sistema standard accettabili. **Vietate** animazioni custom o effetti vistosi sul solo toggle (allineato a **D-12**). | Animazione accensione icona | Efficienza e sobrieta'. | Approvata |
| D-10 | **Layout header (decisione unica, vincolante)**: area destra dell'`HStack` header = **slot a larghezza fissa** che ospita **due** elementi in sequenza fissa: (1) torcia (2) chiusura. Quando il toggle torcia **non** deve essere mostrato (`!ready` o torcia non disponibile): nel suo posto va un **placeholder non interattivo** **44×44 pt** (stessa «impronta» del target tap del toggle) — **Color.clear** o `Spacer` dimensionato, **senza** `Button`, **senza** controllo con `opacity(0)` (evita ambiguita' hit testing e VoiceOver su elementi fantasma). Il placeholder deve essere **escluso dall'albero accessibilita'** (`accessibilityHidden(true)` o equivalente) così non ruba focus ne' annuncia «vuoto». **Vietato** alternare tre pattern diversi: solo **slot fisso + placeholder 44×44** quando la torcia non c'e'. | `ZStack`+opacity sullo stesso button; slot variabile; solo Spacer senza dimensione fissa | Layout stabile (titolo e chiusura non saltano); hit target prevedibile; a11y chiara (solo il toggle reale e' elemento accessibile). | Approvata |
| D-11 | **Icon-only** resta confermato; **accessibilita'** tramite chiavi `scanner.torch.*` (label/value/hint) + hit target 44×44 (D-7). | Etichetta visibile | Allineato a D-2 e sezione accessibilita'. | Approvata |
| D-12 | **Toggle torcia — UX sobria e silenziosa**: il tap sul toggle **non** deve introdurre feedback extra — **nessun** haptic dedicato (niente `UIFeedbackGenerator` / `sensoryFeedback` / equivalenti **solo** per la torcia); **nessun** toast, banner o testo temporaneo tipo «torcia attiva/disattiva»; **nessuna** animazione custom o effetto vistoso oltre quanto gia' vietato in **D-9**. Restano ammessi **solo** i feedback di sistema / flusso **gia' presenti** altrove nello scanner (es. tick tattile/sonoro allo **scan** riuscito nel `Coordinator`), senza duplicarli sul toggle. Motivazione: coerenza con header **minimale** e sobrio. | Haptic «click» sul toggle; Snackbar stato torch | Stesso tono dell'header attuale; niente rumore percettivo. | Approvata |
| D-13 | **Implementazione visiva vincolata al close** (SwiftUI, stesso file dell'header): il bottone torcia deve replicare il **trattamento** del bottone chiusura esistente — **`Button` plain** (nessuno stile promiment/bordered); icona con **`.font(.title2)`** (o **identica** scala effettiva del close se gia' diversa nel codice, ma **stessa** del close nella stessa build); **`foregroundStyle(.white.opacity(0.9))`** o valore **letteralmente allineato** al modificatore del close; **`.shadow(radius: 4)`** (o stesso `shadow` del close) **solo** se il close lo usa — se il close non ha ombra, **nessuna** ombra aggiuntiva sulla torcia; **frame** / hit target **minimo 44×44** (coerente **D-7**). Obiettivo: in execution non introdurre una variante «quasi uguale» ma non identica. | Stile diverso dal close; ombra solo sulla torcia | Pixel-parita' percettiva con l'header esistente. | Approvata |

---

## Planning (Claude) — completo (2026-03-25)

### Obiettivo
Introdurre un toggle **torch/flashlight** nel flusso **`ScannerView`**, con architettura **SwiftUI-first**, applicazione **thread-safe** su `sessionQueue`, ciclo di vita **sicuro** (sempre OFF dove richiesto), **aspetto nativo dell'header esistente** (**D-8**, **D-13**), **header a slot fisso** (**D-10**), **UX silenziosa sul toggle** (**D-12**), localizzazione e **VoiceOver** coerenti, senza nuove dipendenze e senza logica duplicata nei call site.

### Analisi (repo reale)
- **`ScannerScreenState`** (`BarcodeScannerView.swift`): `.ready` e' l'unico stato operativo con overlay istruzioni; `.startingSession` mostra gia' il preview ma non l'overlay «laser». Il toggle deve apparire **solo** in `.ready` per rispettare D-3 e CA-5.
- **`BarcodeScannerView`**: `Coordinator` possiede `AVCaptureSession`, `sessionQueue`, `configureSessionIfNeeded()`, `teardownSession()`, `dismantleUIView` → `teardownSession()`. Qualsiasi `torchMode` / `isTorchActive` va applicato sul **device di input** gia' aggiunto alla sessione, **dentro** `sessionQueue`, con controlli `device.hasTorch` e, se necessario, `device.isTorchModeSupported(.on)`.
- **`ScannerView`**: gia' usa `@Environment(\.scenePhase)` e `handleScenePhaseChange`; `handleCodeScanned` chiama `onCodeScanned` poi `dismiss()`. La torcia va spenta su questi percorsi oltre che nel Coordinator.
- **Riuso**: tutto il flusso scanner e' incapsulato nel file del componente; gli ingressi `ScannerView` sono solo sheet elencati dall'output attuale di `rg '\\bScannerView\\('` (vedi «File coinvolti») — **nessun** accoppiamento torcia previsto.

### Single source of truth (contratto stato)
- **`ScannerView`**: possiede **solo** stato UI — `torchRequestedOn` (intenzione utente) e `isTorchAvailable` (aggiornato **esclusivamente** tramite `onTorchAvailabilityChanged` dal Coordinator su main, mai dedotto con euristiche nella view). Nessun accesso diretto ad `AVCaptureDevice` in SwiftUI.
- **`Coordinator`**: **unico** modulo che **legge e scrive** lo stato **hardware** della torcia (`torchMode` / lock configurazione). Nessun altro tipo nel progetto deve impostare la torch per questo flusso.
- **Availability**: flusso **unidirezionale** Coordinator → SwiftUI tramite `onTorchAvailabilityChanged` (main); SwiftUI **non** deduce `hasTorch` da supposizioni locali.
- **Call site** (`GeneratedView` / `DatabaseView`): **zero** logica torch; zero binding torcia.
- **Punti unici consigliati (naming indicativo, adattare se necessario)**:
  - **`resetTorchUIState()`** (su `ScannerView`, `private`): imposta `torchRequestedOn = false` e, se serve allineamento post-errore, invoca solo aggiornamento verso il representable; chiamarlo da dismiss, background/inactive, uscita da `.ready`, dopo fallimento torch (CA-8), e all'onAppear coerente con D-5. **Nota**: puo' essere invocato **dentro** `closeScannerAndResetTorch()` cosi' il reset non resta duplicato su piu' rami.
  - **`closeScannerAndResetTorch()`** (su `ScannerView`, `private`, nome indicativo): **un solo** helper SwiftUI su cui **convergono** la **chiusura manuale** (tap X) e la **chiusura post-scan riuscito** — evita divergenze future tra i due percorsi. Deve centralizzare in ordine logico: (1) **reset stato UI torcia** (es. tramite `resetTorchUIState()` o equivalente); (2) **coordinamento con il representable** prima del dismiss (garantire `desiredTorchOn == false` propagato cosi' il Coordinator riceve l'aggiornamento; se serve un ciclo di layout/runloop minimo per l'apply, tenerlo **qui** e non sparpagliato); (3) **`dismiss()`** finale della sheet. Percorso scan: eseguire prima `onCodeScanned(code)` poi **`closeScannerAndResetTorch()`** (callback utente prima della chiusura); percorsi **solo** UI (background, errori torch, uscita da `.ready`) continuano a usare `resetTorchUIState()` **senza** dismiss dove non serve chiudere la sheet.
  - **`applyDesiredTorchState()`** e/o **`setTorchStateIfPossible()`** (su `Coordinator`, invocati **solo** da `sessionQueue`): unica implementazione di accensione/spegnimento hardware + notifiche di coerenza verso main se necessario; `teardown` e scan-success devono passare da qui o da helper interni che **sempre** estinguono la torch prima di smantellare.

### Architettura implementation-ready (SwiftUI-first)
1. **`ScannerView` (SwiftUI)**  
   - Mantiene `@State private var torchRequestedOn` e `@State private var isTorchAvailable` come da contratto SSOT.  
   - Passa a `BarcodeScannerView` **`desiredTorchOn`** derivato da `torchRequestedOn && isTorchAvailable` (o equivalente documentato).  
   - Centralizzare i reset UI in **`resetTorchUIState()`** dove serve **senza** chiudere la sheet; per **ogni** uscita che include `dismiss()`, far convergere **chiusura manuale** e **post-scan** su **`closeScannerAndResetTorch()`** (vedi SSOT) invece di duplicare reset + dismiss in due punti del file.  
   - **Header**: implementare **D-10** (slot destro a larghezza fissa = torcia + chiusura; placeholder 44×44 non interattivo + `accessibilityHidden` quando manca il toggle), **D-8** + **D-13** (mirror SwiftUI del close: `Button` plain, `title2`, `foregroundStyle`, shadow solo se il close ha shadow, 44×44), **D-12** (nessun haptic/toast/banner/extra sul toggle).

2. **`BarcodeScannerView` (`UIViewRepresentable`)**  
   - Parametri: `desiredTorchOn: Bool` + **`onTorchAvailabilityChanged: (Bool) -> Void`**.  
   - `updateUIView`: propagare al Coordinator e schedulare **`applyDesiredTorchState()`** / **`setTorchStateIfPossible()`** su `sessionQueue`.

3. **`Coordinator`**  
   - Implementare **`applyDesiredTorchState()`** (e se utile **`setTorchStateIfPossible()`** come sotto-step) **solo** su `sessionQueue`: guard su sessione running, `hasTorch`, teardown; spegnimento sempre su percorsi di uscita.  
   - **`teardownSession()`** / scan riuscito: torch **OFF** prima di fermare/smontare (CA-2, CA-3).  
   - Dopo fallimento configurazione torch (sotto): chiamare main per `onTorchAvailabilityChanged` / callback opzionale «torch failed» se serve solo per `resetTorchUIState()` — **senza** nuovi stati schermata.

4. **Nessuna logica torch** fuori da `BarcodeScannerView.swift` (oltre stringhe localizzate).

### Fallback errori configurazione torch (oltre a «device senza torch»)
Se **`lockForConfiguration`** fallisce, o **`torchMode = .on`** / spegnimento non riescono, o si riceve eccezione dal device:
- **Nessun** `alert` e **nessun** nuovo `ScannerScreenState` o vista dedicata «torch error».
- **Sempre** riallineare a **OFF**: chiamare **`resetTorchUIState()`** su `ScannerView` (da callback main dal Coordinator se necessario) cosi' il toggle non resta in stato ON illusorio.
- Sul **Coordinator**: best-effort **spegnimento** torch e continuazione sessione **se ancora valida**; priorità: scan e preview funzionanti > torch accesa.
- Il toggle resta **visibile solo** se `isTorchAvailable` resta true dal device; se l'errore implica torcia non piu' utilizzabile, aggiornare availability via callback e nascondere il controllo (D-4).
- Comportamento verificabile con **CA-8** e test su device reale se possibile (simulare difficile — accettabile STATIC + code path review se non riproducibile).

### Lifecycle e sicurezza (obbligatorio)
Spegnimento **esplicito** torcia in tutti i casi seguenti (implementazione sul **device** in `sessionQueue`, stato UI allineato su **main**):
- **Dismiss manuale** (tap chiudi): usare **`closeScannerAndResetTorch()`** (reset UI + propagazione verso representable + `dismiss`) — non duplicare lo stesso ordine di operazioni altrove.  
- **Scan riuscito**: hardware/spengo gia' nel `Coordinator` sul `sessionQueue`; lato SwiftUI, dopo `onCodeScanned(code)` invocare lo **stesso** **`closeScannerAndResetTorch()`** cosi' reset UI + dismiss restano allineati al percorso manuale.  
- **`dismantleUIView` / `teardownSession()`**: gia' citato; non uscire con torch accesa.  
- **`scenePhase` `.inactive` / `.background`**: in `handleScenePhaseChange` (o equivalente), impostare `torchRequestedOn = false` e passare `desiredTorchOn` false al representable; il Coordinator con `shouldRunSession` gia' legato a `scenePhase == .active` deve comunque **spegnere torcia** quando la sessione non e' attiva o in transizione.  
- **Errori / fallback** che portano fuori da `.ready` (`handleSessionSetupFailed`, transizioni a `permissionDenied`, ecc.): `torchRequestedOn = false` e torcia hardware spenta; toggle **non** mostrato (CA-5).

**Foreground**: al ritorno `.active`, **non** riaccendere automaticamente la torcia; UI resta **OFF** (CA-4, D-5).

### Localizzazione e accessibilita'
Aggiornare **tutti** i file esistenti `Localizable.strings` del progetto (**it**, **en**, **es**, **zh-Hans**) con chiavi **nuove** dedicate (prefisso coerente `scanner.torch.*`):

| Chiave | Uso |
|--------|-----|
| `scanner.torch.accessibility.label` | Ruolo controllo (es. «Torcia») — `accessibilityLabel` base se si usa anche `value`. |
| `scanner.torch.accessibility.value.on` | VoiceOver **value** stato acceso (es. «Accesa»). |
| `scanner.torch.accessibility.value.off` | VoiceOver **value** stato spento (es. «Spenta»). |
| `scanner.torch.accessibility.hint` | **Hint** unico coerente (es. attiva/disattiva luce per leggere il codice). |

**VoiceOver**: combinare **label** + **value** dinamici ON/OFF (o, se preferito in implementation, `accessibilityLabel` composita localizzata che cambia tra due stringhe — documentare scelta in Execution); l'**`accessibilityValue`** (o equivalente) deve riflettere lo **stato effettivo** della torcia **dopo** recovery / error handling, **non** la sola intenzione utente se questa e' stata annullata dal Coordinator.  
- *Esempio concettuale*: utente richiede **ON** → applicazione torch **fallisce** → UI riallineata a **OFF** (`resetTorchUIState` / CA-8) → VoiceOver deve annunciare **OFF**, non **ON**.

Nessun testo visibile obbligatorio accanto all'icona (controllo icon-only); stringhe solo per accessibilita' / eventuale debug.

### Rischi / edge case (non rompere)
- **Race** tra tap veloci e `applyDesiredTorchState`: serializzare tutto su `sessionQueue`; idempotenza spegni/accendi.  
- **Simulator / device senza torch**: `onTorchAvailabilityChanged(false)` prima possibile; nessun assert.  
- **Sessione ferma** mentre `desiredTorchOn` e' true: hardware deve restare spento; al `startRunning` successivo non riaccendere se policy e' «solo se utente ha richiesto» — con reset OFF su background/dismiss il rischio e' contenuto.  
- **Errori API torch**: vedi sezione «Fallback errori configurazione torch» e CA-8.  
- **Regressione TASK-020**: non alterare testi o layout dei `ScannerFallbackView` / stati non operativi salvo necessita' assoluta.

### Vincoli invariati (obbligatori — direzione confermata, senza cambio perimetro)
- Toggle torcia **solo** in **`screenState == .ready`** con device torch disponibile (**D-3**, **CA-5**).  
- Stato iniziale a ogni apertura sheet: **OFF** (**D-5**, **CA-6**).  
- **Nessuna** persistenza preferenza torcia (**D-6**).  
- **Nessuna** logica torch nei call site; **nessuna** logica torch fuori da `BarcodeScannerView.swift` (salvo `Localizable.strings`).  
- Spegnimento **esplicito** su dismiss manuale, scan riuscito, **inactive/background**, **teardown** / `dismantleUIView` (come da lifecycle nel task).  
- Errori API torch: **fallback silenzioso** (nessun alert, nessuno stato UI dedicato) come **CA-8** e sezione fallback.  
- **Stile plain** coerente con il bottone close (**D-8**, **D-13**); **slot header fisso** con placeholder **44×44** quando il toggle non c'e' (**D-10**); toggle **silenzioso** — **D-12** (niente haptic/toast/banner/extra sul tap torcia).  
- **Nessuna** nuova dipendenza (SPM / CocoaPods / altro).  
- **Nessuno** scope creep e **nessun** refactor non necessario dei flow scanner esistenti (TASK-020, permessi, `refreshScannerState`); modifiche minime e localizzate.

### Riferimento Android (solo funzionale)
Benchmark UX: presenza toggle torcia nello scanner Android; nessun porting codice.

### Test manuali (dettagliati)
**Device fisico vs Simulator (vincolante)**  
- **Comportamento reale della torcia** (luce, accensione/spegnimento hardware, CA-2/3/4 legati al LED): verificare **solo su device fisico** con torch (iPhone).  
- **Simulator** (e, se applicabile, device senza torch): verificare **solo** assenza del **toggle interattivo** ove previsto, **D-10** / fallback coerenti, **nessuna regressione** TASK-020, nessun crash — **non** usare il Simulator come prova affidabile del comportamento torch.

- **T-1** — **Solo device reale**, ambiente **buio**: da ogni ingresso elencato da `rg '\\bScannerView\\('` (vedi T-2) aprire scanner, accendere torcia, verificare lettura stabile; spegnere e rileggere.  
- **T-2** — **Ingressi `ScannerView`**: rieseguire `rg '\\bScannerView\\(' --glob '*.swift'` e coprire **tutti** i file/occorrenze emersi (l'elenco numerico nel task e' **indicativo** finché non si rilancia il comando). Aggiornare T-2/T-9/handoff se l'output differisce dallo **ultimo esito noto** in «File coinvolti».  
- **T-3** — **Solo device reale**: chiusura con torcia accesa → dismiss con X → luce **OFF subito**.  
- **T-4** — **Solo device reale**: scan con torcia accesa → al beep/vibrazione e chiusura sheet → torcia **OFF immediata** (CA-2).  
- **T-5** — **Solo device reale**: con torcia accesa, background → torcia off; foreground → toggle e hardware **OFF**, nessun auto-on.  
- **T-6** — **Simulator** (e/o device senza torch): nessun **toggle torcia interattivo** ove atteso; slot destro **D-10** (placeholder 44×44, `accessibilityHidden`); nessun crash; **non** validare l'LED.  
- **T-7** — **Permesso camera negato** / **restricted**: schermata fallback TASK-020; **nessun** toggle torcia (Simulator o device ok per messaggi UI).  
- **T-8** — **Localizzazione e accessibilita'**: preferibilmente **device reale** per VoiceOver sul toggle in `.ready`; verificare label/value/hint; dopo un fallimento torch simulato o reale, **value** = **OFF** coerente con CA-8 e sezione accessibilita'.  
- **T-9** — **Scenario combinato end-to-end** (**solo device reale** con torch): usare almeno **due** ingressi distinti tra quelli elencati dall'**ultimo** `rg '\\bScannerView\\('` (se l'output include sia `GeneratedView` sia `DatabaseView`, coprirli entrambi; se un file sparisce o ne compare un altro, adeguare i passi). Sequenza: apri → torcia on → chiudi → riapri subito → **OFF** (UI + hardware) → torcia on → background → foreground → **OFF** → scan → dismiss finale → **OFF**.

### Handoff post-planning → EXECUTION (Codex)
- **Prossima fase**: EXECUTION  
- **Prossimo agente**: CODEX  
- **Azione consigliata**: implementare in **`iOSMerchandiseControl/BarcodeScannerView.swift`** secondo **SSOT**, **`resetTorchUIState()`**, **`closeScannerAndResetTorch()`** (convergenza close manuale / post-scan), **`applyDesiredTorchState()`** / **`setTorchStateIfPossible()`**, lifecycle e **fallback errori torch**; aggiornare **`it` / `en` / `es` / `zh-Hans`** `Localizable.strings` (`scanner.torch.*`). **`accessibilityValue`** allineato allo **stato effettivo** post-recovery (vedi sezione accessibilita').  
- **Call site**: **non** fidarsi dei numeri nel task come verità definitiva — rieseguire `rg '\\bScannerView\\(' --glob '*.swift'` a inizio execution e prima del merge; se l'output diverge dallo **ultimo esito noto** in «File coinvolti», aggiornare **File coinvolti**, **T-2**, **T-9** e questo handoff nello stesso turno. **Non** modificare i file call site salvo imprevisto di firma (non atteso).  
- **Device vs Simulator**: prove su **luce LED / torch on-off** e scenari T-1/3/4/5/9 **solo device fisico**; Simulator solo per assenza toggle, D-10, fallback, regressioni, crash (come intestazione «Test manuali»).  
- **Decisioni UI vincolanti**: **D-1…D-13** — **D-8** + **D-13** (mirror concreto del close: `Button` plain, `title2`, `.white.opacity(0.9)`, shadow solo se il close, 44×44), **D-10** (slot fisso, placeholder, no `opacity` fantasma), **D-12** (toggle silenzioso: no haptic dedicato, no toast/banner, no animazioni custom vistose sul toggle).  
- **Edge case**: stati non `.ready`; CA-8; TASK-020; `sessionQueue` unica; teardown e scan-success sempre torch off.  
- **Vincoli**: sezione **«Vincoli invariati»** (toggle solo `.ready`, OFF iniziale, no persistenza, no torch nei call site, spegnimenti espliciti, fallback silenzioso, **D-8**/**D-10**/**D-12**/**D-13**, no dipendenze, no scope creep).  
- **Verifica post-implementazione**: **CA-1…CA-8** + **T-1…T-9**; build Debug; aggiornare **Execution** e **Handoff post-execution**.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Implementare il toggle torcia del flusso scanner iOS nel solo perimetro definito dal task: stato UI in `ScannerView`, stato hardware nel `Coordinator`, spegnimento esplicito nei lifecycle richiesti, localizzazioni `scanner.torch.*`, nessuna logica torch nei call site esterni.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-026-scanner-toggle-torcia-flashlight.md`
- `iOSMerchandiseControl/BarcodeScannerView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `rg '\bScannerView\(' --glob '*.swift'` rieseguito sul tree sincronizzato: `DatabaseView.swift` = 1 call site; `GeneratedView.swift` = 3 call site; nessuna divergenza rispetto all'ultimo esito noto nel task.

### Piano minimo
- Estendere `ScannerView` con `torchRequestedOn`, `isTorchAvailable`, `resetTorchUIState()` e `closeScannerAndResetTorch()`.
- Propagare `desiredTorchOn` al representable e centralizzare nel `Coordinator` `applyDesiredTorchState()` / `setTorchStateIfPossible()` solo su `sessionQueue`.
- Aggiungere le chiavi `scanner.torch.*`, validare build Debug e registrare handoff verso `REVIEW`.

### Modifiche fatte
- In `ScannerView` ho introdotto `torchRequestedOn` e `isTorchAvailable` come stato UI SSOT, con `desiredTorchOn` derivato da `screenState == .ready`, `scenePhase == .active`, richiesta utente e availability dal `Coordinator`.
- Ho aggiunto `resetTorchUIState()` per riallineare la UI a `OFF` e `closeScannerAndResetTorch()` come punto unico per close manuale e close post-scan, mantenendo il dismiss della sheet dopo il reset UI.
- L'header ora usa uno slot destro fisso con due elementi in sequenza: toggle torcia e close. Quando il toggle non deve apparire, al suo posto c'e' un placeholder `44x44` non interattivo e `accessibilityHidden(true)`.
- Il toggle torcia e' icon-only, `Button` plain, `font(.title2)`, `foregroundStyle(.white.opacity(0.9))`, `shadow(radius: 4)`, stesso trattamento del close; nessun haptic dedicato, nessun toast/banner, nessuna animazione custom.
- In `BarcodeScannerView` ho aggiunto `desiredTorchOn`, `onTorchAvailabilityChanged` e `onTorchStateResetRequested`; `makeUIView` e `updateUIView` inoltrano lo stato completo al `Coordinator` senza modificare i call site esterni di `ScannerView`.
- Nel `Coordinator` ho centralizzato la torcia su `sessionQueue` con `applyDesiredTorchState()` e `setTorchStateIfPossible()`, memorizzando il `captureDevice`, aggiornando l'availability verso SwiftUI e facendo fallback silenzioso con best-effort OFF + reset UI quando l'accensione fallisce.
- Lo spegnimento torcia e' esplicito su scan riuscito (`metadataOutput`), dismiss manuale tramite reset UI + teardown, `scenePhase` inactive/background, `handleSessionSetupFailed`, teardown/dismantle e uscita dagli stati non operativi.
- Ho aggiunto le quattro chiavi `scanner.torch.accessibility.{label,value.on,value.off,hint}` in `it`, `en`, `es`, `zh-Hans`; `accessibilityValue` del toggle segue lo stato UI effettivo post-recovery (`torchRequestedOn` dopo eventuale reset).
- Verifica rapida Info.plist/build settings: `INFOPLIST_KEY_NSCameraUsageDescription` e' gia' presente nel `project.pbxproj`; nessuna modifica necessaria.

### Verifica criteri di accettazione
- `CA-1` — ✅ ESEGUITO (`STATIC`/`BUILD`): toggle disponibile solo in `.ready` con `isTorchAvailable == true`; tap ripetuti serializzati da `sessionQueue`; `desiredTorchOn`, `applyDesiredTorchState()` e `setTorchStateIfPossible()` evitano logica hardware fuori dal `Coordinator`.
- `CA-2` — ✅ ESEGUITO (`STATIC`): su scan riuscito il `Coordinator` porta `desiredTorchOn = false`, applica OFF sul device e poi ferma la sessione; lato SwiftUI il percorso converge su `closeScannerAndResetTorch()`.
- `CA-3` — ✅ ESEGUITO (`STATIC`): il bottone close usa `closeScannerAndResetTorch()`; `dismantleUIView` richiama `teardownSession()`, che imposta `desiredTorchOn = false` e forza OFF prima/durante il teardown.
- `CA-4` — ✅ ESEGUITO (`STATIC`): su `scenePhase` `.inactive`/`.background` `ScannerView` chiama `resetTorchUIState()`; `shouldRunSession` passa a `false`, il `Coordinator` spegne la torcia e al ritorno `.active` non c'e' alcun ripristino automatico.
- `CA-5` — ✅ ESEGUITO (`STATIC`): il toggle e' visibile solo con `screenState == .ready && isTorchAvailable`; negli altri casi l'header mostra solo placeholder `44x44` non interattivo, senza opacity hack e senza pulsante disabilitato.
- `CA-6` — ✅ ESEGUITO (`STATIC`): ogni nuova presentazione parte con `torchRequestedOn = false`; `onAppear` richiama anche `resetTorchUIState()` per mantenere OFF come default di apertura.
- `CA-7` — ✅ ESEGUITO (`BUILD`/`STATIC`): build Debug riuscita; flusso scanner TASK-020 mantenuto, nessuna logica torch aggiunta nei call site, nessuna modifica a fallback permessi/camera oltre al reset torcia sugli stati non operativi.
- `CA-8` — ✅ ESEGUITO (`STATIC`): errori `lockForConfiguration`/set torch non aprono alert o nuovi stati UI; il `Coordinator` prova a forzare OFF, chiede il reset UI via callback e `accessibilityValue` torna coerente a `OFF`.

### Check eseguiti
- ✅ ESEGUITO — Sync con remoto e verifica tree: `git fetch --all --prune`; `git rev-list --left-right --count HEAD...origin/main` = `0 0`. `git pull --ff-only` ha restituito `fatal: Cannot fast-forward to multiple branches.`, ma senza divergenza remota reale da sincronizzare.
- ✅ ESEGUITO — Call site finali scanner: `rg '\bScannerView\(' --glob '*.swift'` conferma 4 invocazioni totali (`DatabaseView` 1, `GeneratedView` 3); nessuna divergenza, quindi nessun aggiornamento a "File coinvolti", `T-2`, `T-9` o bullet call site dell'handoff planning.
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build` -> `** BUILD SUCCEEDED **`.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: la build e' verde e non segnala warning sui file modificati; restano warning/note generiche dell'ambiente (`multiple matching destinations`, `Metadata extraction skipped`) e manca una baseline automatica nello stesso turno per dimostrare formalmente l'assenza assoluta di warning nuovi.
- ✅ ESEGUITO — Modifiche coerenti con il planning: rispettati SSOT, helper SwiftUI richiesti, gestione torcia su `sessionQueue`, spegnimenti espliciti, no persistenza, no logica torch nei call site, no dipendenze nuove.
- ✅ ESEGUITO — Criteri di accettazione verificati: copertura statica di `CA-1...CA-8` sui rami implementati + build Debug verde; test manuali/device restano esplicitamente pendenti.

### Rischi rimasti
- I comportamenti LED reali di `T-1`, `T-3`, `T-4`, `T-5` e `T-9` non sono stati eseguiti su device fisico in questo turno; l'ordine di spegnimento e l'assenza di flash residuo restano verificati solo staticamente.
- Il ramo di fallback `lockForConfiguration` / errore hardware torch e' coperto nel codice ma non e' stato riprodotto manualmente su device reale; serve validazione runtime per chiudere definitivamente `CA-8`.
- `git pull --ff-only` richiede probabilmente un riallineamento locale della configurazione upstream, ma non ha bloccato l'execution di TASK-026 perche' `HEAD` e `origin/main` erano gia' allineati.

### Aggiornamenti file di tracking
- Aggiornati i campi globali di questo task a `REVIEW / CLAUDE`.
- Aggiunto l'handoff post-execution con file modificati, decisioni UI rispettate, esito call site, test eseguiti e rischi residui.
- `docs/MASTER-PLAN.md` riallineato alla transizione valida `EXECUTION -> REVIEW` senza modificare backlog o priorita'.

---

## Handoff post-execution
- _(snapshot storico post-execution; stato corrente del task: **BLOCKED** — review **APPROVED**, test manuali **T-1…T-9** pendenti; vedi **Informazioni generali** e **Review**.)_
- **Fase completata**: EXECUTION -> REVIEW
- **Prossimo agente**: CLAUDE
- **File modificati**:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-026-scanner-toggle-torcia-flashlight.md`
  - `iOSMerchandiseControl/BarcodeScannerView.swift`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- **Decisioni UI rispettate**: toggle nell'header subito prima del close; icon-only; stile plain e stessa famiglia visiva del close (`title2`, `.white.opacity(0.9)`, `shadow(radius: 4)`); slot fisso con placeholder `44x44`; nessun `opacity(0)` su controllo fantasma; nessun haptic dedicato; nessun toast/banner; nessuna animazione custom vistosa.
- **Call site**: `rg '\bScannerView\(' --glob '*.swift'` rieseguito dopo sync remoto -> `DatabaseView.swift` 1, `GeneratedView.swift` 3; nessuna differenza rispetto all'ultimo esito noto; nessuna modifica ai call site esterni.
- **Test eseguiti**: sync remoto/fonte di verita' call site, verifica rapida `INFOPLIST_KEY_NSCameraUsageDescription`, build Debug iphonesimulator verde, review statica `CA-1...CA-8`.
- **Test rimasti manuali**: `T-1...T-9` del task, con particolare focus device fisico per LED/torch (`T-1`, `T-3`, `T-4`, `T-5`, `T-8`, `T-9`) e Simulator/device senza torch per `T-6` / `T-7`.
- **Rischi residui reali**: manca una validazione manuale su device fisico dell'ordine di spegnimento torcia su dismiss/scan/background e del fallback runtime di `CA-8`; il resto del comportamento richiesto e' coperto staticamente e da build.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Esito
- **APPROVED** — criteri **CA-1…CA-8** soddisfatti per quanto verificabile con **STATIC**/**BUILD** (come documentato in **Execution**); **nessun fix** richiesto dalla review; **nessun fix aperto** emerso dalla review.

### Evidenza sintetica
- Build **Debug** riuscita (come da execution/handoff Codex).
- Allineamento codice al planning (**SSOT** torcia, lifecycle, **D-8**/**D-10**/**D-12**/**D-13**, localizzazioni `scanner.torch.*`) coerente con le sezioni **Planning** / **Execution**.

### Residui / rischi noti (non bloccanti per l’esito review)
- **Test manuali** **T-1…T-9** **non ancora eseguiti** in questo turno (device fisico per LED/torch, matrice completa come da task).

### Nota sospensione (tracking utente 2026-03-25)
- **In sospensione / pending manual validation** — il task **non** passa a **DONE** senza validazione manuale.
- **Riattivare** (rimuovere **BLOCKED** o ripristinare flusso operativo sul file task + **MASTER-PLAN**) per eseguire **T-1…T-9** manualmente **prima della chiusura finale**; poi: eventuale **FIX** solo se emergono regressioni → **REVIEW** → **conferma utente** → **DONE**.

### Handoff post-review (verso ripresa / chiusura)
- **Prossima azione consigliata (alla ripresa)**: esecuzione **T-1…T-9** su device/Simulator come da sezione «Test manuali»; se OK → **conferma utente** in **Chiusura** → **DONE**.
- **Prossimo agente operativo alla ripresa**: utente / **CODEX** solo se servono fix post-test; **CLAUDE** solo se serve nuova review dopo fix.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

_(vuoto)_

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- _(eventuale persistenza preferenza utente «torcia default on» — fuori scope default TASK-026)_

### Riepilogo finale
_(al DONE)_

### Data completamento
_(al DONE)_
