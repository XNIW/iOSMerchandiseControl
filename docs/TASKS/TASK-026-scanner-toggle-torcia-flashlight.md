# TASK-026: Scanner — toggle torcia (flashlight)

## Informazioni generali
- **Task ID**: TASK-026
- **Titolo**: Scanner: toggle torcia (flashlight)
- **File task**: `docs/TASKS/TASK-026-scanner-toggle-torcia-flashlight.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 *(bootstrap planning iniziale; attivazione da backlog audit iOS vs Android 2026-03-25)*
- **Ultimo agente che ha operato**: CLAUDE

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
- Impostazioni globali persistenti «ricorda torcia accesa» (salvo decisione esplicita successiva in planning — default: **no** scope creep).
- Allineamento riga-per-riga col codice Kotlin (solo **riferimento funzionale**: presenza toggle e UX attesa).

## File potenzialmente coinvolti
- `iOSMerchandiseControl/BarcodeScannerView.swift` — `BarcodeScannerView` (`UIViewRepresentable`), `ScannerView`, sessione `AVCaptureSession` / `AVCaptureDevice`.
- `iOSMerchandiseControl/GeneratedView.swift` — sheet `ScannerView` (inventario).
- `iOSMerchandiseControl/DatabaseView.swift` — sheet `ScannerView` (database).
- Stringhe localizzazione (`*.lproj` / `L(...)`) — etichetta / accessibilita' toggle (es. «Torcia», hint VoiceOver).
- Eventuale **Info.plist** — verificare se capability gia' coperta da uso camera esistente (nessun nuovo permesso testuale atteso se la camera e' gia' autorizzata).

## Criteri di accettazione (iniziali — da rifinire in planning completo)
- [ ] **CA-1**: Con camera attiva e device che **supporta** torcia su camera posteriore, l'utente puo' **attivare/disattivare** la torcia tramite controllo dedicato nello **scanner**; stato coerente (on/off) e **nessun crash** se il toggle viene premuto piu' volte.
- [ ] **CA-2**: All'**uscita** dallo scanner (dismiss sheet / chiusura sessione), la torcia viene **spenta** (nessun flash lasciato acceso in background salvo vincolo tecnico documentato).
- [ ] **CA-3**: Se il device **non** supporta torcia o non e' disponibile, il controllo e' **nascosto** o **disabilitato** con UX chiara (no pulsante «morto» senza feedback — dettaglio in planning).
- [ ] **CA-4**: **Build Debug** compila senza errori; nessun nuovo warning **evitabile**; nessuna regressione **TASK-020** (stati camera non disponibile / messaggi gia' introdotti).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| — | *(da compilare dopo analisi codice reale: posizione UI toggle, icona SF Symbol vs testo, persistenza stato)* | — | — | — |

---

## Planning (Claude) — bootstrap (2026-03-25)

### Obiettivo
Fornire un **toggle flashlight** affidabile nel flusso **`ScannerView`**, allineato alle API iOS (`AVCaptureDevice.torchMode` / equivalenti supportati), con ciclo di vita sicuro e testi localizzati.

### Contesto tecnico (da approfondire)
- La sessione di cattura vive in **`BarcodeScannerView`**; il coordinator deve poter **legare** torch on/off alla sessione e al thread corretto (coda sessione gia' presente nel file).
- Verificare **thread-safety** e ordine: sessione `startRunning` prima di abilitare torcia se richiesto dalla piattaforma.

### Approccio proposto (bozza)
1. Leggere **`BarcodeScannerView.swift`** e mappare dove viene configurato `AVCaptureDevice` / session.
2. Aggiungere stato **`torchOn`** (o simile) in **`ScannerView`** con binding verso il layer UIKit se necessario (`Coordinator` + metodo su `BarcodeScannerView`).
3. Esporre un **pulsante** (toolbar overlay o area sicura) con icona tipo `flashlight.on.fill` / `flashlight.off.fill` e **accessibilityLabel** localizzato.
4. Su `onDisappear` / teardown sessione: forzare **torch off** e gestire errori senza crash.
5. **Grep** tutti i call site di **`ScannerView`** per assicurarsi che il comportamento sia uniforme (Generated + Database).

### Rischi / edge case
- Device **senza** torch (iPod touch, simulator): UI deve degradare senza error log rumorosi.
- **Sessione non ancora pronta**: tap precoce sul toggle — ignorare o no-op sicuro.
- **Interruzione** (phone call, background): torcia si spegne a livello sistema; riallineare stato UI al rientro se possibile (o reset a off).
- **Battery / heat**: nessun obbligo di limitazione in questo task; eventuale follow-up prodotto fuori scope.

### Riferimento Android (solo funzionale)
- Presenza di un **controllo torcia** nello scanner Android come **benchmark UX**; nessuna copia di implementazione o API.

### Test manuali previsti (bozza)
- **T-1**: Device reale, ambiente scuro — aprire scanner da **Inventario** e da **Database**; torcia on → scan riuscito; torcia off.
- **T-2**: Chiudere sheet con torcia on → verificare che la luce si spenga.
- **T-3**: Simulator o device senza torch → controllo assente o disabilitato senza crash.
- **T-4**: Negare permesso camera (se gia' coperto da TASK-020) — nessuna regressione messaggi; torcia non deve apparire se sessione non attiva.

### Handoff (bootstrap — **non** ancora verso EXECUTION)
- Il planning **non** e' ancora completo ai sensi del protocollo (mancano analisi dettagliata su file, decisioni UI definitive, handoff formale con tutti gli elementi obbligatori).
- **Prossimo passo**: **CLAUDE** completa **Analisi** su codice reale, tabella **Decisioni**, **Rischi** aggiornati, **CA** finali e **Handoff → Execution** verso **CODEX**.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

_(vuoto fino a EXECUTION)_

---

## Review (Claude) ← solo Claude aggiorna questa sezione

_(vuoto fino a REVIEW)_

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
