# TASK-072 — Release CTA «Controlla cloud» / «Sincronizza ora» in OptionsView iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-072 |
| **Titolo** | Release CTA «Controlla cloud» / «Sincronizza ora» in OptionsView iOS |
| **File task** | `docs/TASKS/TASK-072-supabase-release-cta-controlla-cloud-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-08 00:24 -04 — Review severa repo-grounded **APPROVED_FIXED_DIRECTLY**; fix copy/localizzazioni/test; build/test/check finali PASS; TASK-072 chiuso **DONE / Chiusura** su override utente. |
| **Ultimo agente** | Codex / Reviewer+Fixer+Closer |

### Nota autorizzazioni (TASK-072)

Questo task è stato promosso a **ACTIVE / EXECUTION** con user override esplicito del 2026-05-07 23:56 -04. Lo storico planning-only precedente resta valido come contesto; l'execution Codex è stata autorizzata solo nel perimetro di questo file.

Durante l'execution sono rimasti non autorizzati:

- `project.pbxproj`, `Info.plist`, risorse Xcode non necessarie;
- migration SQL, `db push`, backend, Android;
- wiring live preview remoto / factory injection live (**TASK-073**).
- sync automatica, Timer, BGTask, Realtime, worker, polling;
- Supabase SDK/RPC diretti in `OptionsView` o nella card Release.

Marcato **DONE / Chiusura** dopo review severa repo-grounded e fix diretto, su override esplicito dell'utente in questo turno.

## Dipendenze

- **Dipende da**: **TASK-071 DONE / Chiusura** (adapter/remoto preview read-only, coordinator con `remotePreviewProvider` opzionale, Release factory ancora senza injection live); **TASK-070 DONE / Chiusura** (policy CTA «Controlla cloud», UX partial vs pending locale, D70-xx); **TASK-067 DONE / Chiusura** (card Release SwiftUI `SupabaseManualSyncReleaseCard`, factory Release, chiavi `options.supabase.manualSync.*`); **TASK-069 DONE / Chiusura** (pending locali reali sul ViewModel); **TASK-066/065 DONE** (ViewModel + coordinator dry-run/mock).
- **Sblocca** (solo dopo EXECUTION futura di TASK-072 quando autorizzata): UX esplicita lato Release per distinguere/controllo cloud vs azione «sincronizza» manuale, come prerequisito per **TASK-073** (wiring live). **TASK-073 non viene creato in TASK-072.**

## Scopo

Definire la progettazione (senza codice in questo task) della **UI Release** in SwiftUI dentro `OptionsView` per rendere operative e chiare sul piano utente due call-to-action manuali (**«Controlla cloud»** e **«Sincronizza ora»** — titoli concettuali, testi finali nelle **quattro lingue**), usando **solo** `SupabaseManualSyncViewModel` e i percorsi gia’ esistenti mediatori (coordinator via DI gia’ cablato in factory/Task-065–067), senza sync automatica ne’ nuovi canali Supabase dalla View.

## Obiettivo

Consegnare un planning **EXECUTION-ready** che permetta, in un task esecutivo futuro autorizzato, di:

1. Rendere evidente nella sezione Release «Sincronizzazione cloud» un **gesto esplicito** utente per **controllare lo stato sul cloud** (lettura/consapevolezza, coerente con preview read-only dopo **TASK-071** quando il provider sara’ disponibile da **TASK-073**).
2. Offrire dove appropriato una CTA dedicata **«Sincronizza ora»** (o equivalenti localizzati) legata allo **stesso ViewModel**, senza suggerire invio automatico o background.
3. Rispettare confini architetturali: **nessun `SupabaseClient`** in `OptionsView`, copy **IT / EN / ES / zh-Hans** senza gergo, accessibilita’ minima conforme alle linee guida Task-067/D70.

Il risultato atteso **di questo planning** è documentazione e criteri; **non** una modifica compilabile finche’ non viene autorizzata l’EXECUTION.

## Stato attuale iOS (repo-grounded)

- **`OptionsView` + `SupabaseManualSyncReleaseCard`**: UI Release affianca la sezione header/footer gia’ localizzati (`options.supabase.manualSync.*`); una **singola CTA primaria** e’ derivata dagli stati del ViewModel (auth, baseline, pending, running, ecc.) — Task-067.
- **`SupabaseManualSyncReleaseFactory`**: costruisce coordinator + dipendenze **dry-run/mock** production-safe come in Task-067; dopo Task-071 il coordinator accetta **`remotePreviewProvider` opzionale**, ma **la factory Release non lo inietta** → la run pubblica non esegue ancora preview remota reale.
- **`SupabaseManualSyncViewModel`**: espone stati osservabili per copy user-facing e `start`/`cancel` guidati senza networking diretto in View — Task-066/069.

## Riferimenti usati

| Riferimento | Uso nel planning |
|-------------|------------------|
| **TASK-067** | Pattern UI Release card, `@StateObject`, accessibilita’ dinamica CTA, chiavi localization, XCTest Release anti-scope. |
| **TASK-070** | Trigger **solo tap esplicito** per «controllo cloud» (**D70-17…D70-19**), separazione **pending locale** vs **segnali cloud**, partial preview → «Controllo cloud incompleto», cancellazione (**D70-15**). |
| **TASK-071** | Stack tecnico preview (adapter/protocol/summary aggregato **privacy-safe**, no `SyncPreview` in UI Release); **nessuna CTA/UI aggiunta** in quel task → gap coperto qui. |
| **MASTER-PLAN** | Roadmap TASK-072 → 075 sequenza consigliata; **un solo ACTIVE** (questo TASK-072 planning). |

## Differenze / gap

| Aspetto | Dopo TASK-067/069/071 | Gap TASK-072 |
|---------|----------------------|--------------|
| CTA semantiche | Un’azione primaria contestuale (Controlla/Accedi/Riallinea…) | Definire **due intenti utente distinti** (preview read-only vs run guidata) ma **solo una CTA primaria dominante** per stato; preview/sync **solo se capability** dichiarata dal ViewModel (**D72-14**) |
| Preview remota | Pronta in coordinator quando `remotePreviewProvider` non esposto dalla factory Release (**TASK-073**) | UX **capability-driven** (**D72-03**, **D72-14…D72-21**): niente pulsante preview finche’ il ViewModel non espone capacità preview reale; superficie verificabile in EXECUTION con **mock/false capability** (**D72-22**) senza «coming soon» |
| Copy | Gia’ no jargon in stringhe Release | Aggiungere/rafforzare stringhe **quattro lingue** per nuove label CTA (`Controlla cloud`, `Sincronizza ora` e hints) mantenendo divieto termini tecnici |
| Automation | Gia’ vietata | Nessun `onAppear` trigger, Timer, ecc. (**D72-06**) |

## Decisioni TASK-072 (D72)

| ID | Decisione |
|----|-----------|
| **D72-01** | TASK-072 nella fase corrente e’ **solo planning**; non autorizza EXECUTION Swift ne’ PR Xcode fino a review + **user override** esplicito. |
| **D72-02** | Tutte le interazioni Release passano da **`SupabaseManualSyncViewModel`** (o tipi gia’ usati dalla card); **vietato** in `OptionsView` / componenti Release: `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.channel`, networking/SDK diretto (**allineamento D72-18**). |
| **D72-03** | (**Chiusura ambiguita’ — UX capability-driven**) **«Controlla cloud»** e’ **visibile solo** quando il **ViewModel** espone chiaramente la **capability** «preview remota read-only disponibile» (cioè quando DI/coordinator/fornitore permettono quell’azione in modo onesto alla UI — tipicamente dopo **TASK-073**, quando il wiring live pubblica quel segnale al VM). **Vietati**: pulsanti disabilitati ingannevoli, copy «coming soon» / «prossimo aggiornamento», o qualsiasi CTA cloud che suggerisca controllo remoto reale quando la capability non esiste. La superficie TASK-072 può essere progettata e **testata in EXECUTION** con **presentation state mock/fake del ViewModel** (capability on/off, **D72-22**), ma **nell’interfaccia Release** non si mostra un controllo cloud reale finché la capability non è vera. |
| **D72-04** | **«Sincronizza ora»** comunica solo **run manuale guidata** gia’ supportata dal ViewModel/coordinator quando la **capability** corrispondente e’ esposta; **non** promette sync in background **ne’** flush/drain/outbox dall’etichetta; eventuali passaggi con scrittura solo se il flusso coordinator/VM lo consente e con **conferme** gia’ previste dal flusso (non introdotte oppostamente in `OptionsView`). |
| **D72-05** | Vietati: sync automatica, **Timer**, **BGTask**/BackgroundTasks, **Realtime**, **worker**, **polling**, retry loop nascosti. |
| **D72-06** | Vietato innesco automatico della preview/controllo cloud su `onAppear`, su cambio stato «tutto aggiornato», o dopo aggiornamento pending locale (**allineamento D70-17**). |
| **D72-07** | Nessuna migration, SQL, `db push`, modifica RPC/RLS/schema, Kotlin/Android/backend; nessuna nuova orchestrazione di rete aggiunta in `OptionsView`. |
| **D72-08** | Nessun nuovo **apply/pull/push/drain/enqueue** se non tramite percorsi gia’ esistenti nel coordinator ViewModel/Task-065–069; **`Controlla cloud`** specificamente **senza** apply/push/drain (**D72-15**). |
| **D72-09** | Mantenere **`SupabaseManualSyncReleaseFactory`** piccola in EXECUTION: eventuali nuovi pulsanti non devono costruire servizi nella View (**allineamento Task-067**); capability booleane / enum presentazionale **nel ViewModel**, non branching tecnico nella View. |
| **D72-10** | Stringhe Release visibili: **solo** `Localizable` **IT / EN / ES / zh-Hans** in merge EXECUTION (**D72-19** rafforza no jargon). |
| **D72-11** | **Accessibilita’**: `accessibilityLabel` coerente con il titolo pulsante visualizzato; `hint` quando la CTA e’ disabilitata per **motivi transitori** (auth in corso, operazione in corso) — **non** per «funzione non disponibile» mascherata da disabled permanente (vietato da **D72-21**). Stato **loading** / **Annulla** annunciabili. |
| **D72-12** | **TASK-074** gestira’ il summary finale ricco — TASK-072 **non** duplica quel lavoro: solo messaggi brevi di stato coerenti con **Copy UX consigliato** e ViewModel. |
| **D72-13** | Nessun **`SyncPreview`** né identificatori riga (barcode/UUID/liste) nella UI pubblica (**D70-07**, Task-071). |
| **D72-14** | **Una sola CTA primaria dominante alla volta** (priorita’ indicativa: non autenticato → `Accedi`; baseline mancante → `Riallinea dati`; preview read-only disponibile → `Controlla cloud` se e solo se capability; run guidata reale disponibile → `Sincronizza ora` se e solo se capability; running → progress + `Annulla`; errore/cancellazione → messaggio breve + `Riprova` solo quando il ViewModel indica retry sicuro). **Vietate** due CTA **borderedProminent** affiancate. |
| **D72-15** | **`Controlla cloud`** = sola **lettura / preview read-only** orchestrata dal coordinator; **nessun** apply locale, **nessun** push/drain/enqueue tramite questa CTA. |
| **D72-16** | **`Sincronizza ora`** = **run manuale guidata** (potenzialmente con modifiche **solo** se coordinator/ViewModel lo supportano gia’); eventuali conferme restano nel flusso esistente, non introdotte dalla sola `OptionsView`. |
| **D72-17** | **`OptionsView` / card Release** non decide guardando dettagli tecnici (provider, fasi interne, tipi servizio): consuma **solo stato presentazionale** / capability esposte da **`SupabaseManualSyncViewModel`** (o modelli di presentazione ad esso collegati). |
| **D72-18** | Vietato in `OptionsView` e nella card Release: `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.channel`, **Realtime**, **Timer**, **BGTask**, **worker**, **polling** (eco **D72-02**, **D72-05**). |
| **D72-19** | Copy Release: vietati termini **DTO**, **SyncPreview** raw, **RPC**, **outbox**, **payload**, **UUID**, **liste barcode** e analoghi; allineamento test anti-jargon Task-067. |
| **D72-20** | **Una sola card / sezione** Release per cloud sync, coerente con **stile e layout Task-067** in `OptionsView`; **non** due card separate «cloud» vs «sync». |
| **D72-21** | **Capability-driven assoluto**: nessun pulsante **non funzionante**, nessuna CTA **sempre visibile** che confonda (es. doppia primaria); nessun testo che **prometta** funzione cloud reale senza capability corrispondente. |
| **D72-22** | **Pre-TASK-073**: l’implementazione puo’ includere test ViewModel/UI con **flag capability falsi** per verificare che la UI **non mostri** `Controlla cloud` ne’ prometta sync reale; quando le capability sono false, la card resta onesta (es. solo stati gia’ possibili oggi: auth, baseline, messaggi locali, eventuale azione guidata **solo** se gia’ realmente disponibile). |

## Perimetro

- Documentazione pianificazione + eventualmente refinement del file task (**solo markdown** durante PLANNING fino ad EXECUTION).
- In EXECUTION futura quando autorizzata: modifiche contenute alla **Superficie Release** (`OptionsView` / struct private card / stringhe **`options.supabase.manualSync.*` o chiavi dedicate coerenti**); eventuale estensione minima **`SupabaseManualSyncViewModel`** **solo se** indispensabile per distinguere azioni (**senza** rete/SDK nella View).

## Fuori perimetro

- Iniettare in Release factory **`SupabaseManualSyncPullPreviewAdapter`** / provider preview live (**TASK-073**).
- Riepilogo finale completo degli step di run (**TASK-074**) e smoke operativo dataset (**TASK-075**).
- Modifiche **`project.pbxproj`** non necessarie oltre l’aggiunta inevitabile di file Swift **solo in EXECUTION futura**.
- XCTest **`sim_ui`** sperimentale, prove live obbligatorie in PLANNING review.

## State matrix UX proposta

Tabella orientativa per **presentation state** espresso dal **`SupabaseManualSyncViewModel`**. Una sola **CTA primaria** dominante (`.borderedProminent`), salvo stato **running** dove il focus e’ progress + **`Annulla`**. Una **secondaria** (`.bordered` o testo) solo se **non** compete visivamente (**D72-14**, **D72-21**).

| Stato | Titolo / descrizione utente | CTA primaria | CTA secondaria | Note |
| --- | --- | --- | --- | --- |
| **Non autenticato** | Accesso richiesto per usare il cloud (messaggio sintetico) | **`Accedi`** | — | Mantiene sensibilità Task-067 (**D72-14**) |
| **Baseline mancante / da riallineare** | Prima allinea i dati locali prima del cloud | **`Riallinea dati`** | — | Nessun **`Controlla cloud`** prima di baseline (**D72-14**) |
| **Pending locali**, preview **non** disponibile (`canCheckCloud == false`) | Modifiche locali da gestire nella run guidata; nessuna verifica cloud reale ora | **`Sincronizza ora`** *solo se* capability run guidata reale (**D72-04**, **D72-21**); altrimenti copy informativa + messaggio eventualmente guidato dagli stati VM **senza CTA cloud finta** | — | **Non** promettere cloud senza wiring (**D72-03**, **D72-22**) |
| **Preview remota disponibile** (`canCheckCloud == true`), nessuna run sync primaria più urgente | Puoi vedere una lettura sicura sul cloud (**read-only**) | **`Controlla cloud`** | — | Solo tap manuale; **nessun apply/push/drain** (**D72-15**) |
| **Run guidata reale disponibile** + eventualmente anche preview disponibile | Sincronizzazione manuale possibile (**D72-16**) | **`Sincronizza ora`** | **`Controlla cloud`** solo se il ViewModel segnala entrambi e la secondaria resta `.bordered` / non prominente (**D72-14**) | Evitare peso visivo duplicato (**D72-21**) |
| **Running** | Operazione in corso (**Copy UX**) | — (indicator + testo stato) | **`Annulla`** | Accessibility: progress/stato (**D72-11**) |
| **Errore retry-safe** | Operazione non completata | **`Riprova`** (solo se VM `canRetry` o equivalente) | — | Messaggio corto privacy-safe, no jargon (**D72-19**) |
| **Fallito senza retry** / blocco | Messaggio sintetico + eventuale accedi / riallinea se applicabile | CTA ricondotta al **motivo dominante** (es. **`Accedi`**, **`Riallinea dati`**) | — | Nessuna CTA orfana |
| **Cancellazione** | Operazione interrotta | Messaggio sintetico; **`Riprova`** solo quando sicuro (**D72-14**) | — | Non presentare successo dopo cancel (**coerenza D70-15**) |
| **Idle / «nessun lavoro» sincrono** locale | Nessuna modifica da sincronizzare (copy sober) | Se preview capability: **`Controlla cloud`** discretamente; altrimenti **nessuna** CTA sync finta | — | **Non** affermare «cloud aggiornato» senza esito preview reale (**D72-03**, TASK-069/071) |

*I nomi `canCheckCloud`, `canRetry`, ecc. sono **placeholder pianificatorio** — in EXECuzione il ViewModel userà tipi/esistenti o nuovi enum di presentazione coerenti (**D72-17**, **D72-22**).*

## UX proposta

### Struttura (card unica **D72-20**)

1. **Una sola card** Release nel blocco **`OptionsView`**, continuando lo **stesso stile compatto Task-067** (header sezione già previsto **D70-19**, non competizione con `#if DEBUG`).
2. Gerarchia visiva chiara interna alla card **verticale** su iPhone: **Titolo stato** corto (`headline`/simile alla card attuale) → **sottotitolo** massimo **1–2 righe** → facoltativo **chip / status badge discreto** (tono neutro).
3. **CTA**: un solo pulsante `.buttonStyle(.borderedProminent)` per stato (**eccezione running**: contenuto primario = progress/indicatore; **`Annulla`** come pulsante `.bordered` non concorrente con una seconda «primaria»). Eventuale seconda azione con `.buttonStyle(.bordered)` o **solo testo/link** quando strettamente necessario (**non** affiancare due prominenti).
4. **Layout adattivo**: preferire colonne **`VStack`**; **`HStack` / `ViewThatFits`** solo se la larghezza e la tipografia mantengono **leggibilità** e una sola primaria (**D72-14**, **D72-21**).
5. **`Controlla cloud` / `Sincronizza ora`**: apparizione **solo** se capability dichiarata dal ViewModel (**D72-03**, **D72-15**, **D72-16**); nessuna CTA “placeholder”.
6. **DEBUG**: una sola eccezione strutturale — card tecnica **`#if DEBUG`** resta separata (**Task-067**).

## Copy UX consigliato

Bozze **italiane** come **fonte di verità contenutistica** per il planning; le stringhe **`Localizable` IT / EN / ES / zh-Hans** saranno **finalizzate in EXECUTION** con **parity di significato**, **senza jargon** (**D72-10**, **D72-19**) e coperte da **test anti-jargon / coverage** (**§Test plan**, **§Localizzazioni previste**).

| Ruolo copy | Bozza italiana (concept) |
|-----------|---------------------------|
| **Titolo sezione** | Sincronizzazione cloud |
| **Descrizione sezione / footer** | Controlla e sincronizza i dati manualmente quando vuoi. |
| **CTA preview read-only** | Controlla cloud |
| **CTA run guidata** | Sincronizza ora |
| **Signed-out / serve accesso** | Accedi per usare il cloud |
| **Baseline** | Riallinea dati |
| **Running** | Operazione in corso… |
| **Annulla** | Annulla |
| **Errore / fallimento soft** | Controllo non completato. Riprova tra poco. |
| **Cancellazione** | Operazione annullata. |
| **Idle / nessuna modifica da sync** | Nessuna modifica da sincronizzare. |

*Le varianti stato-specifiche definitive restano agganciate allo **state matrix** e alla tassonomia errori privacy-safe (`SupabaseManualSyncUserFacingCopy` / equivalenti) durante EXECUTION.*

## Localizzazioni previste

Chiavi suggerite (prefisso **`options.supabase.manualSync`** già usato). Completare tutte le chiavi di **§Copy UX consigliato** + stato matrix in **IT / EN / ES / zh-Hans** in EXECUTION; **test anti-jargon** e parity di significato obbligatori.

| Chiave suggerita | IT (draft) | Note |
|------------------|-----------|------|
| `cta.checkCloud.title` | Controlla cloud | Visibility solo con capability preview (**D72-03**, **D72-15**) |
| `cta.syncNow.title` | Sincronizza ora | Visibility solo con capability run guidata (**D72-04**, **D72-16**) |
| Hint / messaggi transitori (auth, ecc.) | Tutte lingue in EXECUTION | Solo stati transitori (**D72-11**); mai copy «prossima versione» (**D72-21**) |

Ogni altra stringa visibile in Release va elencata prima del merge e coperta da `plutil` + scan duplicati + test **`SupabaseManualSyncReleaseUITests`** / no-jargon (**§Test plan**, parità Task-067).

## Test plan (futura EXECUTION — non eseguito in PLANNING TASK-072)

Quando EXECUTION autorizzata, **Codex** documenta PASS/FAIL nei propri check:

| Tipo | Cosa |
|------|------|
| **XCTest ViewModel** | `SupabaseManualSyncViewModelTests`: regressioni + casi **capability false** (**D72-22**) — nessun mapping UI che mostri `Controlla cloud` / `Sincronizza ora` senza capability corrispondente; nessun leakage SDK. |
| **XCTest UI/statici Release** | Estendere `SupabaseManualSyncReleaseUITests`: presenza chiavi nuove, **grep no-jargon** su `options.supabase.manualSync.*`, separazione `#if DEBUG` vs Release. |
| **Grep anti-scope** | `OptionsView`/card Release: vietati `BGTask`, `Timer`, `Realtime`, `worker`, `.channel`, `SupabaseClient`, `.rpc`, `.from`, `.upsert` (come Task-067 + **D72-18**). |
| **plutil** | `Localizable.strings` IT / EN / ES / zh-Hans. |
| **Duplicati chiavi** | Script o procedura repo esistente sui quattro `.lproj`. |
| **Build** | Debug + Release Simulator (scheme `iOSMerchandiseControl`) — **solo in EXECUTION**, non ora. |

## Rischi

| Rischio | Mitigation (planning) |
|---------|---------------------|
| CTA **Controlla** vs **Sync** (ambiguità terminologica) | **State matrix** + **capability-driven** (**D72-14…D72-16**); copy **§Copy UX consigliato**; seconda CTA solo `.bordered`. |
| **`Controlla cloud` mostrata senza wiring reale / senza capability** | Vietato da **D72-03**, **D72-21**, **D72-22** — test ViewModel + Review checklist. |
| Scope creep wiring live dentro TASK-072 | Confine esplicito: injection = **solo TASK-073**; questo task pianifica superficie soltanto. |
| Accessibilita’ regressione | Checklist §Review con VoiceOver smoke manuale in EXECUTION. |

## Definition of Ready (EXECUTION futura — gate)

Prima che **TASK-072** possa passare da **planning reviewed** a **EXECUTION**:

- [ ] **D72-03 chiusa**: **capability-driven**, nessun CTA non funzionale / «coming soon», **nessun** `Controlla cloud` senza preview remota disponibile al ViewModel (**D72-03**, **D72-21**, **D72-22**).
- [ ] Presente e approvata **§State matrix UX proposta** (allineata a **D72-14** «una CTA primaria alla volta»).
- [ ] Regola obbligatoria: **UI capability-driven** (**D72-17**) + **card unica** (**D72-20**).
- [ ] Presente **§Copy UX consigliato** (+ elenco chiavi `Localizable` da estendere in EXECUTION) con richiesta di **quattro lingue** complete e test anti-jargon.
- [ ] Conferma: nessuna injection `remotePreviewProvider` live in `SupabaseManualSyncReleaseFactory` dentro TASK-072 (**TASK-073**).
- [ ] Handoff EXECUTION compilato nel file task con file Swift elencati minimi.
- [ ] **User override** esplicito: **PLANNING → EXECUTION**.

## Definition of Done (planning — questo documento TASK-072 ora)

Planning considerato completato quando:

- [x] Questo file creato nel path MASTER-PLAN **`File task`**.
- [x] MASTER-PLAN aggiornato: **TASK-072 ACTIVE / PLANNING**; progetto **ACTIVE**; **TASK-073–075 TODO**.
- [x] Sezioni obbligatorie del brief utente compilate (**Obiettivo … Review checklist**).
- [x] **2026-05-07 — Refinement UX**: **D72-03 chiusa** (capability-driven); aggiunta **§State matrix UX proposta**, **§Copy UX consigliato**, decisioni **D72-14…D72-22**, DoR/Requisiti UX aggiornati.
- [ ] **Planning Review** Claude + utente (**non** questo turno Codex).

## Handoff

| Verso | Contenuto |
|-------|-----------|
| **Prossima fase** | Dopo Planning Review **APPROVED** + **user override** esplicito → **EXECUTION** (Codex). |
| **Prossimo agente** | **Claude / Reviewer** (planning review) → poi **Codex / Executor** se EXECUTION autorizzata. |
| **Azione consigliata** | Completare **Review checklist** verso **APPROVED planning**; implementare in EXECUTION solo dopo **user override** — fino ad allora **NON READY FOR EXECUTION**. |

### Handoff verso EXECUTION (da compilare solo dopo review **APPROVED**)

*Template — non valido finche’ non esplicitamente sbloccato:*

- Aggiornare `OptionsView.swift` (card Release).
- Aggiornare `it`/`en`/`es`/`zh-Hans` `Localizable.strings`.
- Aggiornare `SupabaseManualSyncReleaseUITests.swift` (e ViewModel tests se nuovi ingressi pubblici sul VM).
- Eseguire build/test dalla matrice §Test plan.

## Review checklist

- [ ] **Perimetro/Fuori perimetro**: coerenti con MASTER-PLAN backlog TASK-072–075.
- [ ] Nessuna contraddizione con **TASK-071** (**no SyncPreview/UI** tecnica pubblica).
- [ ] Copia **non** contiene jargon vietato nei file Release target (**D72-19**).
- [ ] Trigger solo manuale; nessuna automazione progettata (**D72-06**).
- [ ] Accessibilita’ pianificata per label/hint/**transient disabled**/loading/**signed-out** (**D72-11**).
- [ ] **Nessuna CTA** «coming soon» / non funzionante / sempre visibile fuori capability (**D72-03**, **D72-21**).
- [ ] **`Controlla cloud`**: non suggerisce apply/push/drain (**D72-15**); compare solo se capability (**D72-03**).
- [ ] **`Sincronizza ora`**: assente quando non esiste capability run guidata reale (**D72-04**, **D72-21**).
- [ ] Coerenza visiva **OptionsView**/card **Task-067** (**D72-20**) — primaria **borderedProminent**, secondaria max **bordered**.
- [ ] **TASK-073** resta incaricato di **wiring live** / factory injection preview — TASK-072 **non la sostituisce**.
- [ ] Nessun comando **build/test** obbligatorio per chiudere **solo planning** questo file (review primariamente documentale).

## Criteri di accettazione (contratto EXECUTION quando sbloccato)

Applicabili dopo passaggio autorizzato a **EXECUTION**; durante **PLANNING** si intendono come obiettivi di design.

- [ ] **CA72-01**: Card Release (**Task-067**) con slot UI/localized keys per **`Controlla cloud`** e **`Sincronizza ora`** quando le **capabilities** sono esposte dal ViewModel (**D72-03**, **D72-14**, **state matrix**); **IT / EN / ES / zh-Hans** complete; **nessuna** delle due etichette forzata in UI quando capability false (**D72-22**).
- [ ] **CA72-02**: Nessun `SupabaseClient`/SDK/`network`/`.rpc`/`.from`/`.upsert`/`.channel` diretto da `OptionsView`/card (**D72-02**, **D72-18**).
- [ ] **CA72-03**: Nessuna sync automatica, Timer, BGTask, Realtime, worker, polling.
- [ ] **CA72-04**: Nessuna migration/SQL/backend/Android; nessuna nuova apply/push/drain path oltre coordinator/ViewModel esistenti.
- [ ] **CA72-05**: XCTest/`plutil`/grep anti-scope/duplicate keys/build Debug+Release documentati nei check Codex (**come Task-067**).
- [ ] **CA72-06**: Card DEBUG resta **`#if DEBUG`** separata.

## Execution (Codex)

### Obiettivo compreso

Implementare la superficie Release nativa della card **Sincronizzazione cloud** in `OptionsView`, rendendola guidata da un solo stato presentazionale del ViewModel, con una sola CTA primaria per stato, copy localizzato e capability false come default Release finche' il wiring live preview remoto non sara' TASK-073.

### File modificati

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `docs/TASKS/TASK-072-supabase-release-cta-controlla-cloud-ios.md`
- `docs/MASTER-PLAN.md`

### Piano minimo applicato

1. Aggiungere nel ViewModel un modello presentazionale unico con capability esplicite e azioni presentazionali.
2. Rendere la card Release in `OptionsView` solo un renderer dello stato presentazionale, senza branching tecnico.
3. Localizzare copy e azioni IT / EN / ES / zh-Hans senza gergo Release.
4. Aggiornare test ViewModel/statici per capability false, singola primaria, running/cancel, no falso "cloud aggiornato", no jargon e anti-scope.
5. Verificare build, test e check statici; quindi handoff a REVIEW.

### Modifiche fatte

- Aggiunto `SupabaseManualSyncPresentationState` con titolo, sottotitolo, badge testo/SF Symbol, azione primaria, azione secondaria, `isRunning`, `isLoading`, `accessibilityLabel`, `accessibilityHint`.
- Aggiunti tipi di supporto `SupabaseManualSyncCapabilitySet`, `SupabaseManualSyncAuthPresentationContext` e azioni presentazionali per `signIn`, `checkCloud`, `syncNow`, `realign`, `retry`, `cancel`.
- `SupabaseManualSyncReleaseFactory` usa capability Release correnti false/false: niente **Controlla cloud** e niente **Sincronizza ora** se la capability reale non e' disponibile.
- `OptionsView` renderizza `viewModel.presentationState`, con CTA primaria `.borderedProminent`, secondaria `.bordered`, badge con simbolo, `ProgressView` in running e feedback dentro la card.
- Aggiornate localizzazioni IT / EN / ES / zh-Hans per la card Release e le nuove azioni/stati.
- Sostituito il copy "Tutto aggiornato" lato user-facing con "Nessuna modifica da sincronizzare." per evitare promessa di cloud verificato.
- Estesi i test ViewModel e Release UI/statici per matrice capability-driven, una sola primaria, running/cancel, no gergo, localizzazioni complete/duplicate e anti-scope.
- **Review fix diretto**: reso il footer/idle copy capability-neutral, rimosse chiavi Release ormai inutilizzate (`action.check`, `action.checkAgain`, `action.tryAgain`, `action.running`, `accessibility.primaryAction`) e aggiunti test statici per una sola `.borderedProminent` e factory senza preview live.
- Nessun TASK-073 creato; nessun wiring live preview remoto aggiunto.

### Check eseguiti

- ✅ ESEGUITO — Build Debug Simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` PASS.
- ✅ ESEGUITO — Build Release Simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` PASS.
- ✅ ESEGUITO — XCTest mirati `SupabaseManualSyncViewModelTests` + `SupabaseManualSyncReleaseUITests`: PASS, 32 test, 0 failure.
- ✅ ESEGUITO — Regressioni sync/outbox/coordinator rilevanti: PASS, 305 test, 0 failure.
- ✅ ESEGUITO — `plutil -lint` su `Localizable.strings` IT / EN / ES / zh-Hans: PASS.
- ✅ ESEGUITO — Scan duplicate localization keys sui quattro `Localizable.strings`: PASS.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Grep anti-scope su `OptionsView`/card/ViewModel/Release factory per `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.channel`, `Timer`, `BGTask`, `Realtime`, `worker`, `polling`: PASS.
- ✅ ESEGUITO — Scan no-jargon/no falso "cloud aggiornato" sulle stringhe Release `options.supabase.manualSync.*`: PASS.
- ✅ ESEGUITO — Modifiche coerenti con planning: PASS, rispettate D72-03/D72-14/D72-17/D72-18/D72-19/D72-20/D72-21/D72-22.
- ✅ ESEGUITO — Criteri di accettazione CA72-01...CA72-06 verificati staticamente/build/test: PASS.

### Note warning

- Le build emettono warning noti/preesistenti fuori perimetro: AppIntents metadata senza dipendenza `AppIntents.framework`; warning Swift 6 in `SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`.
- Nessun warning rilevato nei file modificati da TASK-072.

### Rischi rimasti

- **Follow-up candidate**: TASK-073 dovra' cablare la preview remota live e solo allora abilitare la capability reale per **Controlla cloud** in Release.
- **Follow-up candidate**: TASK-074 resta responsabile del summary finale ricco user-facing; TASK-072 mantiene solo messaggi brevi nella card.

## Handoff post-execution

| Campo | Valore |
|-------|--------|
| **Fase proposta** | **ACTIVE / REVIEW** |
| **Prossimo responsabile** | **Claude / Reviewer** |
| **Esito execution** | Implementazione TASK-072 completata nel perimetro autorizzato; build/test/check PASS; **non DONE**. |
| **Da verificare in review** | Capability false in Release reale, singola CTA primaria, no falso "cloud aggiornato", no SDK/RPC/Timer/BGTask/Realtime/worker/polling in `OptionsView`/card, localizzazioni complete. |
| **Fuori perimetro confermato** | Nessun TASK-073, nessun wiring live preview remoto, nessun backend/Supabase SQL/RLS/RPC/migration, nessun Android, nessuna sync automatica. |

## Review (Codex)

| Campo | Valore |
|-------|--------|
| **Stato review** | COMPLETATA |
| **Esito review** | **APPROVED_FIXED_DIRECTLY** |
| **Data review** | 2026-05-08 00:24 -04 |

### Sintesi review tecnica

La review repo-grounded conferma che TASK-072 rispetta il perimetro:

- `SupabaseManualSyncPresentationState` e' la superficie presentazionale consumata dalla card Release.
- `OptionsView` / `SupabaseManualSyncReleaseCard` renderizzano stato e azioni senza `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.channel`, Timer/BGTask/Realtime/worker/polling.
- `SupabaseManualSyncReleaseFactory` mantiene capability Release correnti false/false e non inietta `remotePreviewProvider` o adapter live; **TASK-073** resta TODO e non creato.
- Una sola CTA `.borderedProminent` e' dichiarata nella card; eventuale secondaria resta `.bordered`.
- `ProgressView` + `Annulla` sono presenti nello stato running.
- `Controlla cloud` e `Sincronizza ora` non compaiono quando le capability reali sono false; nessun copy Release dice "cloud aggiornato" senza prova remota.
- Localizzazioni IT/EN/ES/zh-Hans complete, senza placeholder divergenti e senza gergo Release vietato.

Problemi piccoli trovati e corretti direttamente:

- Footer/idle copy troppo assertivo ("controlla e sincronizza quando vuoi") mentre le capability Release sono false: reso capability-neutral nelle quattro lingue.
- Chiavi Release non piu' usate rimaste nei `Localizable`: rimosse e test riallineati.
- Test statici rafforzati per singola `.borderedProminent` e assenza di wiring live preview nel factory.

### Check finali post-fix

- ✅ ESEGUITO — Build Debug iPhone 16e OS 26.2: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release iPhone 16e OS 26.2: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — XCTest mirati `SupabaseManualSyncViewModelTests` + `SupabaseManualSyncReleaseUITests`: **32 test**, **0 failure**.
- ✅ ESEGUITO — Regressioni sync/outbox/coordinator rilevanti: **305 test**, **0 failure**.
- ✅ ESEGUITO — `plutil -lint` IT/EN/ES/zh-Hans: PASS.
- ✅ ESEGUITO — Duplicate localization keys IT/EN/ES/zh-Hans: PASS.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Grep anti-scope Release/card/ViewModel/factory: PASS.
- ✅ ESEGUITO — Grep no-jargon/no falso "cloud aggiornato" su `options.supabase.manualSync.*`: PASS.
- ✅ ESEGUITO — Conferme perimetro: no TASK-073, no wiring live preview remoto, no backend/Supabase SQL/Android, no sync automatica, no Timer/BGTask/Realtime/worker/polling, no `SupabaseClient` diretto in `OptionsView`/card.

## Planning (Claude)

### Approccio proposto (EXECUTION-ready)

Implementazione minimale futura (**non eseguita ora**), coerente con **state matrix** e **D72-17**:

1. **ViewModel prima**: definire/aggiungere stato **presentazionale** (capabilities, azione primaria attesa, visibilità secondaria) derivato dai servizi **già injectati** tramite DI; la card legge solo questi campi — **mai** branching su tipi infra in `OptionsView`.
2. **Layout card**: **`VStack`** titolo corto → sottotitolo (max 1–2 righe) → chip stato opzionale → **una** `.borderedProminent` + eventualmente `.bordered`; `ViewThatFits`/`HStack` solo se non crea duplicazione visiva (**§UX proposta**).
3. **`Controlla cloud` / preview**: wired al metodo/azione ViewModel preview-only già mediator verso coordinator; **nessuna** apparizione quando capability è `false`.
4. **`Sincronizza ora`**: wired alla run guidata esistente; **nessuna** apparizione quando capability è `false`.
5. **`SupabaseManualSyncReleaseFactory`**: invariato rispetto a preview live (**TASK-073**); XCTest ViewModel/UI con **capabilities false/true** (**D72-22**).
6. Estendere test anti-jargon / grep scope (**Task-067** parity, **§Test plan**).

## Chiusura

TASK-072 **DONE / Chiusura**.

- Esito: **APPROVED_FIXED_DIRECTLY** dopo review severa repo-grounded.
- File modificati da TASK-072: `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncCoordinatorModels.swift`, `Localizable.strings` IT/EN/ES/zh-Hans, `SupabaseManualSyncViewModelTests.swift`, `SupabaseManualSyncReleaseUITests.swift`, questo file task e `docs/MASTER-PLAN.md`.
- Fix diretti in review: copy capability-neutral, rimozione chiavi localizzazione inutilizzate, test statici extra.
- Rischi residui: **TASK-073** dovra' cablare la preview remota live e abilitare capability reali; **TASK-074** resta responsabile del summary finale ricco.
- Conferme finali: nessun TASK-073 creato o avviato; nessun wiring live preview remoto; nessun backend/Supabase SQL/RLS/RPC/migration; nessun Android; nessuna sync automatica; nessun Timer/BGTask/Realtime/worker/polling; nessun `SupabaseClient` diretto in `OptionsView`/card.
