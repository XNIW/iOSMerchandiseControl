# TASK-075 — Smoke operativo controllato Supabase manual sync iOS

## Titolo e stato (fase corrente)

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-075 |
| **Titolo** | Smoke operativo controllato Supabase manual sync iOS |
| **File task** | `docs/TASKS/TASK-075-supabase-manual-sync-operational-smoke-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 12:07 -0400 — Follow-up P1/P2/P3 eseguiti: dataset piccolo controllato non distruttivo via fixture XCTest, build/test finali PASS, smoke grande/current state Debug/Release caratterizzato come **PARTIAL_EXPECTED** con recovery PASS; TASK-075 chiuso **DONE** su user override. |
| **Ultimo agente** | Codex / Executor+Reviewer+Fixer (user override) |

**TASK-075 DONE / Chiusura.**  
Il planning-only iniziale e' stato superato da user override successivi: preflight, build/test, smoke read-only controllato, review e follow-up **P1/P2/P3** sono stati eseguiti. Le run **S75-b/S75-c** sono state sbloccate con un dataset piccolo controllato **non distruttivo** in test-sandbox/fixture XCTest, senza alterare il dataset grande del Simulator. Il dataset grande/current state resta classificato **PARTIAL_EXPECTED**, non **PASS** naturale, ma e' accettato per closure perche' feedback in corso, cancel, retry, recovery, copy privacy-safe e assenza di mutazioni sono stati verificati in Debug e Release.

---

## Obiettivo

Pianificare uno **smoke operativo controllato** sull’app iOS che esercita il flusso manuale già implementato in **TASK-072 → TASK-074**: autenticazione/baseline/pending dove applicabile, **«Controlla cloud»** (preview remota read-only **S73-a**), **summary user-facing volatile** post-run (**S74-a**), coerenza con outbox/drain **solo come contesto funzionale** (senza cleanup distruttivo).

Risultato atteso **di questa fase**: definizione esplicita di **perimetro smoke**, **PASS/FAIL**, **evidenze** da raccogliere in una execution futura, **regressioni automatiche** da rieseguire, **rischi/rollback non distruttivo**, micro-slice **S75-a…e** e checklist execution **non eseguita ora**.

**Non** si afferma né si documenta come obiettivo che «tutto sia sincronizzato» con il cloud: il controllo rimane **read-only** nel perimetro attuale (`supportsGuidedManualSync` false, nessuna promessa di parità totale).

---

## Stato attuale iOS (dopo TASK-072 / TASK-073 / TASK-074)

| Task | Esito | Rilevanza per TASK-075 |
|------|--------|-------------------------|
| **TASK-072** | DONE / Chiusura | Card Release «Sincronizzazione cloud» in `OptionsView`, `SupabaseManualSyncPresentationState`, CTA capability-driven, localizzazioni IT/EN/ES/zh-Hans. |
| **TASK-073** | DONE / Chiusura (**S73-a**) | Wiring live **preview remota read-only**: `OptionsView` passa `SupabasePullPreviewService`; `SupabaseManualSyncReleaseFactory` costruisce `SupabaseManualSyncPullPreviewAdapter` solo se servizio presente; `supportsRemoteCloudCheck` true solo con provider reale; `supportsGuidedManualSync` sempre false; zero apply/push/drain nel path Release. |
| **TASK-074** | DONE / Chiusura (**S74-a**) | Summary compatto **volatile** post «Controlla cloud», mapping nel `SupabaseManualSyncViewModel`, `OptionsView` rendering-only, chiavi `options.supabase.manualSync.summary.*`, nessuna persistenza summary, nessun raw `SyncPreview` / `RunSummary` in UI Release. |

**Implicazione smoke:** la execution futura valida **controllo cloud + feedback UX** su build **Debug e Release**, con dataset crescente; **non** include `guidedManual` mutativo finche’ non sara’ task separato con override.

---

## Riferimenti iOS da leggere/verificare (pre execution)

### Codice / componenti

| Elemento | Ruolo |
|----------|--------|
| **`OptionsView`** | Sezione Release; card cloud; pass-through servizi al factory; **solo rendering** per summary/stati. |
| **`SupabaseManualSyncViewModel`** | Stati, capability, mapping summary, `start`/`cancel`, presentazione unificata. |
| **`SupabaseManualSyncCoordinator`** | Orchestrazione fasi; preview-only con `remotePreviewProvider`; boundary no SDK diretto nel coordinator. |
| **`SupabaseManualSyncReleaseFactory`** | Composizione dipendenze Release; adapter preview solo con servizio reale. |
| **`SupabaseManualSyncPullPreviewAdapter`** | Implementazione `SupabaseManualSyncRemotePreviewProviding` su `SupabasePullPreviewService`. |
| **`SupabasePullPreviewService`** | Generazione preview read-only remota + confronto con snapshot locale (servizio). |
| **`SyncEventOutboxDrainService`** | Drain **manuale** / contesto operativo (smoke puo’ **osservare** comportamento outbox **senza** reset/truncate). |
| **`SyncEventOutboxEntry`** / **`SyncEventOutboxLocalStore`** (e tipi collegati) | Modello locale outbox; utili per **osservazione** controllata in smoke (no operazioni distruttive). |

### Test esistenti collegati (da rieseguire in execution; **non** obbligatori in questa fase planning)

- **`SupabaseManualSyncViewModelTests.swift`**
- **`SupabaseManualSyncReleaseUITests.swift`**
- **`SupabaseManualSyncRemotePreviewTests.swift`**
- **`SupabaseManualSyncCoordinatorTests.swift`**
- **`SupabaseManualSyncLocalPendingSnapshotProviderTests.swift`**
- **`SyncEventOutboxDrainServiceTests.swift`**, **`SyncEventOutboxLocalStoreTests.swift`**, **`SyncEventOutboxStateTests.swift`**, **`SyncEventOutboxEnqueueServiceTests.swift`**
- **`SyncEventRecordingTests.swift`**, **`SyncEventLiveRecorderTests.swift`**
- **`LocalizationCoverageTests.swift`** (se tocca chiavi `options.supabase.manualSync.*` in change future; **questo planning non modifica Localizable**)

*(Elenco orientativo: affinare in review planning con comandi/scheme esatti del workspace.)*

---

## Riferimento Supabase locale (solo verifica, **senza modifiche**)

- **Path:** `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- **Uso in TASK-075:** **lettura** di schema/migration/RPC gia’ presenti per **`sync_events`** / **`record_sync_event`** (allineamento contrattuale, limiti `changed_count`, idempotenza), **senza** `db push`, migration live, modifiche SQL/RLS/RPC/backend in questo task.
- Eventuali incongruenze backend → **follow-up task** esplicito, non parte dello smoke iOS salvo decisione documentata.

---

## Riferimento Android (solo funzionale)

- **`MerchandiseControlSplitView`** e documentazione sync/outbox/smoke gia’ nel piano Android: utile come **confronto comportamentale** (head-of-line, outbox, manual-first), **non** per modifiche Kotlin/Android in TASK-075.

---

## Perimetro smoke (execution futura)

| ID | Voce | Descrizione |
|----|------|-------------|
| **A** | Dataset piccolo prima | Poche righe/cataloghi; validare latenza UX, assenza crash, messaggi summary coerenti. |
| **B** | Dataset grande dopo | Stress **controllato** (read-only preview); osservare tempi, partial/cancellation, **senza** obiettivo «full sync». |
| **C** | Debug build | Strumenti console/log ammessi solo se gia’ previsti; smoke **non** dipende da UI DEBUG outbox salvo scope esplicito futuro. |
| **D** | Release build | Parita’ capability e copy; **nessun** comportamento solo-DEBUG che mascheri fallimenti Release. |
| **E** | Controlli manuali UI «Controlla cloud» | Tap esplicito; stati idle/running/completato/partial/errore; summary post-run **non** ridondante vs titolo (allineamento **D74-13**). |
| **F** | Evidenze da raccogliere | Screenshot o note strutturate: build config, dataset (ordine di grandezza), esito UI, eventuali log **privacy-safe**; **non** dump di payload/API. |
| **G** | Regressioni automatiche | Rieseguire sottoinsieme XCTest definito in execution (ViewModel/Release/RemotePreview/Coordinator + outbox pertinenti); **non** obbligatorio nel planning-only. |

---

## Criteri PASS / FAIL (operativi, per execution futura)

**PASS (tutti applicabili allo step):**

- App non crasha nel percorso «Controlla cloud» per lo scenario sotto test.
- Copy Release **non** promette sincronizzazione completa/«tutto aggiornato» come esito del solo controllo (coerenza **TASK-074**).
- Summary (se mostrato) coerente con esito dell’ultimo controllo e **non** espone `SyncPreview`/DTO/RPC/outbox nella card.
- Comportamento capability: **nessuna** CTA «Controlla cloud» ingannevole se preview non disponibile (coerenza **TASK-072/073**).

**FAIL:**

- Crash, hang indefinito senza possibilita’ di cancel, o stato incoerente (es. running bloccato senza recovery UX).
- Regressione che espone stringhe/termini vietati in Release (outbox drain come messaggio utente, `record_sync_event`, ecc.) **nelle stringhe visibili** della card.
- Esito dichiarato come successo globale «sync completato con cloud» quando il perimetro e’ solo read-only.

---

## Evidenze richieste per **chiusura futura** TASK-075 (non ora)

- Tabella run: **Debug / Release** × **dataset piccolo / grande** con esito PASS/FAIL e note.
- Elenco **XCTest** eseguiti con esito (numeri test / failure).
- Conferma esplicita: **nessun** truncate/delete/reset outbox eseguito come parte dello smoke (salvo procedura separata autorizzata).
- Link o riferimento a commit/versione app e **stato backend** osservato (lettura-only da clone Supabase), **senza** claim di migrazioni applicate in questo task.

---

## Rischi e rollback non distruttivo

| Rischio | Mitigazione |
|---------|-------------|
| Dataset grande → timeout/partial | Documentare come **esito atteso** parziale; ripetere con rete stabile; **non** forzare retry loop automatici (fuori scope). |
| Confusione utente su “sync” vs “controllo” | Riesaminare copy **TASK-074** prima dello smoke; regression grep no-jargon. |
| Outbox locale in stato intermedio | **Solo osservazione**; **no** cleanup; eventuale STOP smoke e task separato. |
| Drift schema Supabase | Verifica **lettura** su clone; fix backend → **altro task**, non bloccante “per finta” con hack iOS. |

**Rollback:** reinstall app su Simulator/device di test, ripristino backup SwiftData se disponibile in policy di test personale; **nessuna** procedura distruttiva sul backend o truncate outbox come standard di questo task.

---

## Anti-scope esplicito (TASK-075 planning + execution futura salvo nuovo task)

- **No** sync automatica, **Timer**, **BGTask**, **Realtime**, **worker**, **polling** per completare smoke.
- **No** `guidedManual` / `supportsGuidedManualSync = true` senza task e override dedicati.
- **No** apply/pull/push/drain **come obbligo** dello smoke Release read-only (drain resta ambito **DEBUG/manuale** altrove se documentato).
- **No** truncate/delete/reset outbox, **no** cleanup distruttivo dataset.
- **No** `db push`, migration live **SQL/RLS/RPC**, modifiche backend nel perimetro TASK-075.
- **No** modifiche **Android**.
- **No** modifiche **Swift production**, **`project.pbxproj`**, **schema SwiftData**, **`Localizable`** in **questa fase planning** (2026-05-08).
- **No** claim «tutto sincronizzato» o parita’ cloud globale senza prova e senza scope mutativo.

---

## Micro-slice future (indicative)

| Slice | Contenuto |
|-------|-----------|
| **S75-a** | Planning e readiness (questo documento + review planning). |
| **S75-b** | Smoke dataset **piccolo**, **Debug** (execution futura). |
| **S75-c** | Smoke dataset **piccolo**, **Release** (execution futura). |
| **S75-d** | Dataset **grande**, read-only / controllato (execution futura). |
| **S75-e** | Review evidenze e chiusura TASK-075 (solo dopo conferma utente su criteri soddisfatti). |

---

## Checklist execution futura (**NON eseguire ora**)

- [ ] Allineare con reviewer: comandi test (`xcodebuild`/Xcode), simulator/versione OS, account Supabase test.
- [ ] **S75-b:** Debug, dataset piccolo — UI «Controlla cloud» + note evidenze.
- [ ] **S75-c:** Release, dataset piccolo — parita’ UX/capability.
- [ ] **S75-d:** Dataset grande — timeout/partial documentati; STOP se non controllabile.
- [ ] Rieseguire **regressioni XCTest** concordate; registrare PASS/FAIL.
- [ ] Verificare **grep anti-scope** copy Release (se definiti in task precedenti).
- [ ] Aggiornare sezione **Execution** nel file task + **Handoff → Review** (workflow CLAUDE/ CODEX).

---

## Dipendenze

- **Dipende da:** **TASK-072**, **TASK-073**, **TASK-074** (**DONE / Chiusura**).
- **Sblocca:** eventuale roadmap post-smoke (es. `guidedManual` o altri slice) solo come **follow-up** separato.

---

## Handoff (fase PLANNING)

- **Prossima fase:** **PLANNING REVIEW** (affinamento criteri/evidenze; eventuali decisioni **D75-xx** in iterazione successiva).
- **Prossimo agente:** **CLAUDE / Planner** o **utente** per approvazione del planning.
- **Azione consigliata:** **READY FOR PLANNING REVIEW — NON READY FOR EXECUTION.**  
  Nessuna promotion a **EXECUTION** / **Codex** senza review esplicita del planning e **user override** coerente con `MASTER-PLAN`.

---

## Note (turno 2026-05-08)

Nota storica del planning iniziale: le sezioni **Execution**, **Fix**, **Review** erano vuote finche' non fosse iniziata una fase esecutiva autorizzata. User override successivi hanno autorizzato preflight, execution controllata e review; vedere le sezioni successive.

---

## Execution (Codex — setup/preflight)

**2026-05-08 11:06 -0400 — USER OVERRIDE / PREFLIGHT FAIL-FAST, nessuno smoke eseguito.**

### Obiettivo compreso

Eseguire uno smoke operativo controllato del solo flusso iOS read-only **"Controlla cloud"**, senza trasformarlo in full sync, senza `guidedManual`, senza apply/push/drain obbligatorio, senza cleanup outbox, senza modifiche backend/Supabase live e senza Android.

### File controllati

| File / area | Evidenza |
|---|---|
| `docs/MASTER-PLAN.md` | TASK-075 risulta ancora **ACTIVE / PLANNING** e **NON READY FOR EXECUTION**. |
| `docs/TASKS/TASK-075-supabase-manual-sync-operational-smoke-ios.md` | Piano riletto integralmente prima del preflight. |
| `docs/CODEX-EXECUTION-PROTOCOL.md` | Protocollo UI/SIM letto: evidenze `STATIC` / `BUILD` / `SIM` / `MANUAL`, no PASS inferiti. |
| `iOSMerchandiseControl.xcodeproj` | Scheme/configurazioni/destinazioni verificati read-only. |
| `iOSMerchandiseControl/OptionsView.swift` | Lettura statica card Release manual sync, rendering e azioni. |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | Lettura statica capability/actions/summary; `supportsGuidedManualSync` resta false. |
| `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` | Lettura statica wiring Release provider preview opzionale. |
| `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift` | Lettura statica adapter preview read-only. |
| `iOSMerchandiseControl/*.lproj/Localizable.strings` | Grep statico su copy `options.supabase.manualSync.*` e termini tecnici. |
| `/Users/minxiang/Desktop/MerchandiseControlSupabase` | Presenza clone/repo Supabase locale verificata in sola lettura. |

### Piano minimo

1. Confermare preflight richiesto: commit/branch, scheme/comandi, build config, simulator, ambiente Supabase test/clone, dataset piccolo/grande, privacy evidenze.
2. Solo se tutti i preflight sono confermati: eseguire fail-fast Debug + dataset piccolo -> Release + dataset piccolo -> Debug + dataset grande -> Release + dataset grande.
3. Fermarsi al primo blocker/fail senza workaround e senza fix al volo.

### Preflight eseguito

| Voce | Esito | Evidenza / nota |
|---|---:|---|
| Branch/commit iOS | PARTIAL_EXPECTED | Branch `main`; commit `99d17787d604`; workspace dirty con modifiche/untracked gia' presenti su TASK-074/TASK-075, Swift/localizzazioni/test e `docs/MASTER-PLAN.md`. Commit riproducibile solo come `99d17787d604 + working tree dirty`. |
| Scheme/comandi test | PASS | `xcodebuild -list -json -project iOSMerchandiseControl.xcodeproj` conferma scheme `iOSMerchandiseControl`, target `iOSMerchandiseControlTests`. Test class richieste trovate in `iOSMerchandiseControlTests`. |
| Build config Debug/Release | PASS | `xcodebuild -list -json` conferma configurazioni `Debug` e `Release`. |
| Device/simulator/iOS | PASS | `xcodebuild -showdestinations` conferma `iPhone 16e`, iOS `26.2`, destination disponibile; simulator attualmente `Shutdown`, quindi boot/install restano step successivi non eseguiti. |
| Supabase config app | PARTIAL_EXPECTED | `iOSMerchandiseControl/SupabaseConfig.plist` presente, `plutil -lint` PASS, file ignorato da git. Valori non stampati per privacy. |
| Ambiente Supabase test/clone | BLOCKED_ENV | Clone locale `/Users/minxiang/Desktop/MerchandiseControlSupabase` presente e migrations lette in sola lettura; non e' confermabile in modo privacy-safe che il plist dell'app punti al progetto/account Supabase test/clone autorizzato per TASK-075. |
| Dataset piccolo | BLOCKED_ENV | Esiste storico `TASK045_*` nei task precedenti, ma TASK-075 non definisce/approva quale dataset piccolo usare per questo smoke read-only; non inventato. |
| Dataset grande | BLOCKED_ENV | Esiste storico baseline/catalogo grande da TASK-046/TASK-045 (~19698 prodotti remoti / 19698 locali post push), ma lo stato live corrente e l'approvazione come dataset grande TASK-075 non sono confermati. |
| Screenshot/log privacy-safe | PASS_POLICY | Nessuno screenshot/log runtime raccolto. Policy confermata: solo screenshot senza PII visibile e log sanitizzati/conteggi aggregati; niente payload, token, URL sensibili, barcode o UUID grezzi. |
| UI/copy read-only statico | PARTIAL_EXPECTED | Lettura statica: capability Release `supportsGuidedManualSync` false, CTA `checkCloud` disponibile solo con provider preview, summary volatile in ViewModel/card. La chiave `syncNow` esiste nelle localizzazioni ma non risulta attiva con capability corrente; richiede verifica UI reale prima di PASS. |

### Run smoke

| Run | Build config | Dataset | Stato | Evidenza |
|---|---|---|---:|---|
| S75-b | Debug | Piccolo | BLOCKED_ENV | Non eseguita: dataset piccolo e ambiente Supabase test/clone non confermati. |
| S75-c | Release | Piccolo | NOT_APPLICABLE | Non eseguita per fail-fast: S75-b bloccata. |
| S75-d | Debug | Grande | NOT_APPLICABLE | Non eseguita per fail-fast: dataset grande non confermato e S75-b bloccata. |
| S75-d | Release | Grande | NOT_APPLICABLE | Non eseguita per fail-fast: run precedenti non sane/eseguite. |

### Check eseguiti

| Check | Stato | Evidenza / motivo |
|---|---:|---|
| Build compila (Xcode / BuildProject) | ❌ NON ESEGUITO | Stop pre-smoke per blocker preflight; nessun `xcodebuild build` lanciato. |
| Nessun warning nuovo introdotto | ⚠️ NON ESEGUIBILE | Nessuna build eseguita e nessun codice modificato in questa execution setup. |
| Modifiche coerenti con il planning | ✅ ESEGUITO | Nessuna modifica Swift/backend/Android/outbox; solo tracking TASK-075 in sezione Execution. |
| Criteri di accettazione verificati | ⚠️ NON ESEGUIBILE | I criteri PASS/FAIL richiedono run UI "Controlla cloud"; nessuna run eseguita per blocker. |
| Scheme/config/destinazioni disponibili | ✅ ESEGUITO | `xcodebuild -list -json`, `xcodebuild -showdestinations`, `xcrun simctl list devices available`. |
| Supabase plist privacy-safe | ✅ ESEGUITO | `plutil -lint iOSMerchandiseControl/SupabaseConfig.plist` PASS; `git check-ignore` conferma file ignorato. |
| Anti-scope operativo | ✅ ESEGUITO | Nessun full sync, `guidedManual`, push/apply/drain, reset/truncate/delete outbox, migration live, modifica backend, Android o Swift production. |

### Modifiche fatte

- Nessuna modifica codice.
- Nessuna modifica backend/Supabase live.
- Nessuna modifica Android.
- Nessun reset/truncate/delete outbox.
- Aggiornato solo questo file task nella sezione **Execution** con preflight, blocker e handoff.

### Rischi rimasti

- **BLOCKER:** serve conferma esplicita del progetto/account Supabase test/clone collegato all'app, senza esporre segreti.
- **BLOCKER:** serve definizione approvata del dataset piccolo TASK-075.
- **BLOCKER:** serve definizione approvata del dataset grande TASK-075 e conteggio atteso/approssimativo corrente.
- Workspace dirty: le evidenze future devono dichiarare chiaramente `99d17787d604 + working tree dirty` oppure partire da stato committato/stabile.
- La verifica UI reale della CTA unica **"Controlla cloud"** non e' stata eseguita; lettura statica non basta per PASS.

### Handoff post-preflight

- **Prossima fase consigliata:** **BLOCKED / PLANNING REVIEW**, non REVIEW di smoke.
- **Prossimo agente:** utente / Claude per confermare ambiente Supabase test/clone e dataset piccolo/grande.
- **Azione consigliata:** non avviare S75-b finche' i tre blocker sopra non sono risolti. Alla ripresa, partire da Debug + dataset piccolo e applicare la sequenza fail-fast pianificata.

---

### Execution continuation — build/test/smoke non distruttivo

**2026-05-08 11:26 -0400 — USER OVERRIDE / EXECUTION CONTROLLATA PARZIALE.**

L'utente ha confermato esplicitamente:

- commit `99d17787d604`, branch `main`, working tree dirty accettato come evidenza;
- scheme `iOSMerchandiseControl`, simulator `iPhone 16e` iOS `26.2`, config `Debug` e `Release`;
- `SupabaseConfig.plist` presente come configurazione Supabase test per questa execution, senza stampare token/URL/segreti;
- dataset piccolo = stato locale attuale se disponibile; se non piccolo, classificare senza creare/cancellare dati;
- dataset grande = usare solo se disponibile, senza bloccare build/XCTest/smoke base.

#### Comandi eseguiti

| Area | Comando / azione | Esito |
|---|---|---:|
| Git | `git status --short --branch` | PASS: branch `main`; working tree dirty accettato. |
| Git | `git rev-parse --short=12 HEAD` | PASS: `99d17787d604`. |
| Xcode project | `xcodebuild -list -json -project iOSMerchandiseControl.xcodeproj` | PASS: scheme `iOSMerchandiseControl`, config `Debug`/`Release`, target test presente. |
| Destination | `xcodebuild -showdestinations -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl` | PASS: `iPhone 16e`, iOS `26.2`, disponibile. |
| Build Debug | `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/task075-deriveddata build` | PASS: `** BUILD SUCCEEDED **`; log `/tmp/task075_debug_build.log`. |
| Build Release | `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/task075-deriveddata build` | PASS: `** BUILD SUCCEEDED **`; log `/tmp/task075_release_build.log`. |
| XCTest mirati | `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/task075-deriveddata -parallel-testing-enabled NO test -only-testing:...` | PASS: `247 tests`, `0 failures`; xcresult `/tmp/task075-deriveddata/Logs/Test/Test-iOSMerchandiseControl-2026.05.08_11-14-19--0400.xcresult`. |
| Simulator Debug | `xcrun simctl boot`, `bootstatus`, `install`, `launch` su build Debug | PASS: app installata/avviata su `iPhone 16e` iOS `26.2`. |
| Simulator Release | `xcrun simctl terminate`, `install`, `launch` su build Release | PASS: app installata/avviata su stesso simulator. |
| UI automation | `tools/sim_ui.sh show/dump-names/capture` + Computer Use su Simulator | PARTIAL_EXPECTED: automazione usata per navigare, scrollare, tappare e osservare la card. Primo dump filtrato AX ha avuto timeout JXA; retry non filtrato + Computer Use riusciti. |
| Local store read-only | `xcrun simctl get_app_container` + `sqlite3 -readonly .../default.store` | PASS: conteggio dataset locale senza mutazioni. |
| Localizable | `plutil -lint` su IT/EN/ES/zh-Hans | PASS. |
| No-jargon grep | `rg` su chiavi `options.supabase.manualSync.*` per outbox/RPC/drain/SyncPreview/record_sync_event e claim globali | PASS: nessun match. |

#### XCTest eseguiti

Suite incluse nella run:

- `SupabaseManualSyncViewModelTests`
- `SupabaseManualSyncReleaseUITests`
- `SupabaseManualSyncRemotePreviewTests`
- `SupabaseManualSyncCoordinatorTests`
- `SupabaseManualSyncLocalPendingSnapshotProviderTests`
- `SyncEventOutboxDrainServiceTests`
- `SyncEventOutboxLocalStoreTests`
- `SyncEventOutboxStateTests`
- `SyncEventOutboxEnqueueServiceTests`
- `SyncEventRecordingTests`
- `SyncEventLiveRecorderTests`
- `LocalizationCoverageTests`

Esito aggregato: **PASS — 247 test, 0 failure**.

#### Warning build

Le build Debug/Release sono entrambe PASS, ma Xcode ha riportato warning gia' noti/preesistenti nel tracking precedente:

- `SyncEventOutboxDrainService.swift`: accesso a `defaultSendingRecoveryScanLimit` da contesto nonisolated.
- `SupabaseProductPriceApplyService.swift`: accesso a `issueLimit` da contesto nonisolated.
- AppIntents metadata: `No AppIntents.framework dependency found`.

Nessun codice e' stato modificato in questa execution; i warning non sono attribuiti a TASK-075.

#### Dataset osservato

Lettura read-only dello store SwiftData del simulator:

| Entita' | Conteggio |
|---|---:|
| `ZPRODUCT` | `19698` |
| `ZSUPPLIER` | `61` |
| `ZPRODUCTCATEGORY` | `30` |
| `ZPRODUCTPRICE` | `39394` |
| `ZSYNCEVENTOUTBOXENTRY` | `0` |
| `ZSUPABASECATALOGBASELINERUN` | `2` |
| `ZSUPABASECATALOGBASELINERECORD` | `39569` |

Conclusione: lo stato locale attuale **non e' dataset piccolo**; e' dataset grande/current state. Per policy utente non sono stati creati/cancellati dati per costruire un dataset piccolo artificiale.

#### Smoke simulator UI

| Build | Dataset effettivo | Azione | Esito osservato | Classificazione |
|---|---|---|---|---:|
| Debug | Grande/current state | Navigazione `Inventario -> Opzioni`, scroll fino a card, tap `Controlla cloud` | Card visibile; CTA unica `Controlla cloud`; badge `Manuale`; dopo tap: stato `Operazione in corso...`, `ProgressView`, pulsante `Annulla`, nessun blocco globale inutile della schermata. Dopo attesa controllata oltre un minuto la run era ancora running; `Annulla` ha recuperato correttamente con `Operazione annullata.`, summary volatile `Controllo annullato.`, CTA `Riprova`. | PARTIAL_EXPECTED |
| Release | Grande/current state | Install/launch Release, navigazione `Inventario -> Opzioni`, scroll fino a card, tap `Controlla cloud` | Stessa UX base Debug: CTA unica, running localizzato, cancel disponibile, nessun gergo tecnico visibile nella card. Dopo attesa controllata circa un minuto la run era ancora running; `Annulla` ha recuperato correttamente con stato annullato, summary volatile e CTA `Riprova`. Screenshot privacy-safe: `/tmp/task075_release_cancelled_privacy_check.png`. | PARTIAL_EXPECTED |

Note privacy:

- Non sono stati riportati token, URL Supabase, UUID, barcode o payload.
- Le schermate Computer Use mostravano anche stato account nella sezione auth; l'account non viene riportato qui.
- Lo screenshot usato come evidenza finale e' privacy-safe: non mostra email/account/token.

#### Matrice run TASK-075

| Run | Build config | Dataset pianificato | Dataset disponibile | Stato | Evidenza |
|---|---|---|---|---:|---|
| S75-b | Debug | Piccolo | Non disponibile nel simulator corrente | BLOCKED_ENV | Store locale read-only = catalogo grande (`19698` prodotti); nessuna creazione/cancellazione autorizzata. Smoke UI base eseguito comunque sul current state. |
| S75-c | Release | Piccolo | Non disponibile nel simulator corrente | BLOCKED_ENV | Stesso motivo di S75-b; build/test/smoke base eseguiti comunque. |
| S75-d | Debug | Grande | Disponibile/current state | PARTIAL_EXPECTED | UI read-only avviata; running + cancel recovery PASS; completamento naturale non ottenuto nel tempo controllato. |
| S75-d | Release | Grande | Disponibile/current state | PARTIAL_EXPECTED | Parita' UX Release osservata; running + cancel recovery PASS; completamento naturale non ottenuto nel tempo controllato. |

#### Check eseguiti (stato AGENTS)

| Check | Stato | Evidenza / nota |
|---|---:|---|
| Build compila (Xcode / BuildProject) | ✅ ESEGUITO | Debug PASS; Release PASS. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Warning osservati ma gia' noti/preesistenti e fuori perimetro TASK-075; nessun codice modificato. |
| Modifiche coerenti con il planning | ✅ ESEGUITO | Solo smoke read-only; nessun full sync/guidedManual/apply/push/drain obbligatorio/cleanup/backend/Android. |
| Criteri di accettazione verificati | ⚠️ NON ESEGUIBILE integralmente | Crash assente e recovery UI verificata; copy/no-jargon verificati staticamente e in UI; completamento naturale cloud non verificato per dataset grande/current state rimasto running fino a cancel. |
| Smoke UI base | ✅ ESEGUITO | Debug e Release: card raggiunta, CTA unica, tap manuale/equivalente su `Controlla cloud`, stato running, cancel/retry/summary volatile osservati. |
| Dataset piccolo | ⚠️ NON ESEGUIBILE | Non presente nello store locale; non creato per vincolo no data setup distruttivo/non richiesto. |
| Dataset grande | ✅ ESEGUITO parzialmente | Current state grande osservato; run read-only avviata in Debug/Release; cancellata dopo timeout controllato con recovery corretta. |

#### Anti-scope confermato

- Nessun full sync.
- Nessun `guidedManual` / nessun `supportsGuidedManualSync = true`.
- Nessun apply/push/drain obbligatorio.
- Nessun reset/truncate/delete outbox; outbox osservata in read-only con conteggio `0`.
- Nessuna migration live Supabase, nessun `db push`, nessuna modifica backend.
- Nessuna modifica Android.
- Nessuna modifica Swift production, `Localizable`, `project.pbxproj`, schema SwiftData.
- Nessun fix al volo.

#### Bug / follow-up necessari

- **Follow-up candidate P1:** creare o concordare un dataset piccolo non distruttivo per ripetere S75-b/S75-c con completamento naturale atteso.
- **Follow-up candidate P1:** misurare e caratterizzare la durata del read-only preview su catalogo grande/current state (`~19698` prodotti, `~39394` prezzi). In questa execution la UI resta running oltre il tempo controllato ma resta cancellabile; non e' stato forzato un retry loop.
- **Follow-up candidate P2:** valutare una soglia/telemetria privacy-safe per distinguere "dataset grande in corso" da hang reale nella card Release, senza introdurre gergo tecnico.

#### Handoff post-execution controllata

- **Prossima fase consigliata:** **REVIEW** delle evidenze, **non closure**.
- **Prossimo agente:** Claude / Reviewer.
- **Azione consigliata:** verificare se `PARTIAL_EXPECTED` su dataset grande e `BLOCKED_ENV` su dataset piccolo sono accettabili per TASK-075 oppure se serve un micro-task/dataset setup separato prima della chiusura. Nessun fix codice richiesto da questa execution.

---

## Review (Codex — user override)

**2026-05-08 11:44 -0400 — REVIEW + FIX TRACKING, nessun fix Swift.**

> Nota storica: questa review ha correttamente lasciato TASK-075 **BLOCKED / NON DONE** prima dei follow-up P1/P2/P3. Lo stato finale corrente e' nella sezione **Follow-up P1/P2/P3 e chiusura** sotto.

### Obiettivo compreso

Verificare le evidenze dello smoke read-only **"Controlla cloud"** senza trasformarlo in full sync e decidere se TASK-075 puo' andare a **DONE** o deve restare aperto/bloccato.

### File controllati

| File / area | Esito review |
|---|---|
| `docs/MASTER-PLAN.md` | Trovato stale su **TASK-075 ACTIVE / PLANNING**; aggiornato a **BLOCKED / REVIEW**. |
| `docs/TASKS/TASK-075-supabase-manual-sync-operational-smoke-ios.md` | Evidenze Execution oneste ma metadata iniziali stale; aggiornati stato, review e handoff. |
| `iOSMerchandiseControl/OptionsView.swift` | Card Release coerente: una CTA primaria, rendering-only, cancel/retry, summary volatile dal ViewModel. |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | Capability coerenti: `checkCloud` solo con provider preview, `syncNow` gated da `supportsGuidedManualSync`, summary user-facing non raw. |
| `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` | Provider preview costruito solo da `SupabasePullPreviewService`; `supportsGuidedManualSync` resta false. |
| `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift` | Adapter read-only con mapping complete/partial/failed/cancelled privacy-safe. |
| `iOSMerchandiseControl/SupabasePullPreviewService.swift` | Preview remota read-only; nessuna write/apply/push/drain nel percorso esaminato. |
| `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift` | Con provider remoto presente termina dopo `.remotePreview` + `.summary`; nessuna fase mutativa viene avviata. |
| Test TASK-075 collegati | ViewModel, Release UI, RemotePreview, Coordinator, pending/outbox e LocalizationCoverage rieseguiti. |

### Problemi trovati

- **BLOCKER di closure:** dataset piccolo reale non disponibile nel simulator corrente; **S75-b/S75-c** restano **BLOCKED_ENV**, quindi non sono PASS e non vanno dichiarati passati.
- **BLOCKER di closure:** dataset grande/current state e' stato esercitato solo come **PARTIAL_EXPECTED**: UI avviata, running osservato, cancel/recovery PASS, ma completamento naturale del cloud check non verificato.
- **Tracking stale:** metadata del task e `MASTER-PLAN` erano ancora su **ACTIVE / PLANNING** nonostante l'execution controllata fosse gia' documentata.
- Nessun bug Swift piccolo e sicuro da correggere nel perimetro TASK-075; non applicati refactor.

### Decisione dataset piccolo / grande

Scelta esplicita: **B — TASK-075 non va chiusa in DONE senza dataset piccolo reale o accettazione esplicita separata del suo mancato passaggio.**

Motivo: il piano TASK-075 richiede evidenze Debug/Release su dataset piccolo prima del dataset grande; l'execution documenta correttamente **BLOCKED_ENV** per S75-b/S75-c. Build, 247 test e smoke grande/current state sono forti evidenze di non regressione e recovery, ma non sostituiscono il dataset piccolo previsto.

`PARTIAL_EXPECTED` sul dataset grande/current state e' classificazione onesta: non e' FAIL perche' non ci sono crash, gergo tecnico, full sync o blocco senza recovery; non e' PASS completo perche' non c'e' completamento naturale entro il tempo controllato.

### Modifiche fatte

- Nessuna modifica Swift, `Localizable`, backend/Supabase, Android, outbox o dati.
- Fix solo tracking/documentale:
  - metadata TASK-075 aggiornati a **BLOCKED / REVIEW** e **NON DONE**;
  - review Codex aggiunta con decisione su dataset piccolo/grande;
  - `MASTER-PLAN` riallineato allo stato reale.

### Check eseguiti

| Check | Stato | Evidenza / risultato |
|---|---:|---|
| `git status --short --branch` | ✅ ESEGUITO | Branch `main`; working tree dirty con modifiche TASK-074/TASK-075 e fix tracking review. |
| Commit attuale | ✅ ESEGUITO | `99d17787d604`. |
| `xcodebuild -list -json` | ✅ ESEGUITO | Scheme `iOSMerchandiseControl`; config `Debug`/`Release`; target test presente. |
| Build Debug simulator | ✅ ESEGUITO | PASS su `iPhone 16e`, iOS `26.2`; warning solo gia' noti/preesistenti. |
| Build Release simulator | ✅ ESEGUITO | PASS su `iPhone 16e`, iOS `26.2`; warning solo gia' noti/preesistenti. |
| XCTest mirati TASK-075 | ✅ ESEGUITO | PASS: **247 test**, **0 failures**; xcresult `/tmp/task075-review-tests-dd/Logs/Test/Test-iOSMerchandiseControl-2026.05.08_11-40-16--0400.xcresult`. |
| Localizzazioni | ✅ ESEGUITO | `plutil -lint` IT/EN/ES/zh-Hans PASS. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| Grep no-jargon manualSync | ✅ ESEGUITO | Nessun match su chiavi `options.supabase.manualSync.*` per outbox/RPC/drain/SyncPreview/record_sync_event/payload. |
| Smoke Simulator base Release | ✅ ESEGUITO | Card raggiunta in Opzioni; CTA unica **"Controlla cloud"**; running localizzato; `Annulla` recupera a **"Operazione annullata."**, summary **"Controllo annullato."**, CTA **"Riprova"**. Screenshot privacy-safe: `/tmp/task075_review_release_cancelled_privacy_safe.png`. |
| Criteri di accettazione verificati | ⚠️ NON ESEGUIBILE integralmente | S75-b/S75-c dataset piccolo non eseguite; grande/current state non completato naturalmente. |

### Rischi rimasti / follow-up candidate

- **P1:** concordare o creare un dataset piccolo non distruttivo e ripetere **S75-b Debug** + **S75-c Release**.
- **P1:** caratterizzare durata/limiti del preview read-only su catalogo grande/current state senza introdurre retry loop o gergo tecnico in Release.
- **P2:** valutare una soglia di feedback privacy-safe per distinguere "catalogo grande ancora in corso" da hang reale.

### Handoff post-review

- **Verdetto:** **BLOCKED** per closure, con review tecnica OK e nessun fix Swift richiesto.
- **Stato finale TASK-075:** **BLOCKED / REVIEW**, **NON DONE**.
- **Prossimo agente:** utente / Claude per decidere se accettare formalmente l'assenza del dataset piccolo come closure exception oppure aprire/riprendere un follow-up dataset piccolo non distruttivo.
- **Stop rule:** non dichiarare **DONE** finche' S75-b/S75-c non hanno evidenza PASS o finche' l'utente non accetta esplicitamente una closure exception documentata.

---

## Follow-up P1/P2/P3 e chiusura (Codex — user override)

**2026-05-08 12:07 -0400 — P1/P2/P3 eseguiti, TASK-075 DONE.**

### Obiettivo compreso

Sbloccare TASK-075 senza successo finto: creare un dataset piccolo controllato e non distruttivo, verificare Debug/Release, caratterizzare il catalogo grande/current state, applicare solo micro-fix necessari, rieseguire build/test/smoke e chiudere **DONE** solo se le evidenze sono sufficienti.

### Dataset piccolo creato

La soluzione scelta e' stata la piu' sicura disponibile senza cancellare dati reali del Simulator: **fixture XCTest / test-sandbox con provider fake** sul `SupabaseManualSyncCoordinator` e `SupabaseManualSyncViewModel`.

File aggiornato:

- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`

Copertura aggiunta:

- dataset piccolo senza pending locali;
- dataset piccolo con pending locali aggregati;
- preview remota disponibile tramite fake provider privacy-safe;
- running con `ProgressView`, cancel, completed, partial, error, retry;
- summary volatile e non duplicato;
- CTA `checkCloud` senza `syncNow` in capability Release;
- nessun gergo tecnico user-facing;
- prevenzione doppia run concorrente;
- nessuna chiamata mutativa (`catalogPush`, `productPricePush`, `queuedCloudOperationsFlush`).

Nota onesta: il dataset piccolo non e' un nuovo app container reale con login Supabase live; e' un dataset di integrazione controllato in XCTest. Questa scelta e' coerente con l'opzione autorizzata dall'utente ("test integration" / "preview/mock/test provider") e non altera il dataset grande esistente.

### Micro-fix applicati

| File | Fix | Motivo |
|---|---|---|
| `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift` | Aggiunti 5 test TASK-075 small dataset + helper fixture. | Sbloccare S75-b/S75-c in modo non distruttivo e verificabile. |
| `iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift` | Racchiuso il test Debug-only in `#if DEBUG`. | La Release testable compila tutto il target test: il test referenziava un ViewModel produttivo gia' `#if DEBUG`. Fix test-only, nessuna modifica app/outbox runtime. |

Nessuna modifica Swift production, UI production, Localizable, backend/Supabase, Android, dati reali, outbox o schema.

### P2 feedback in corso vs hang

Nessun micro-fix UI production applicato: la card gia' comunica lo stato in modo sufficiente e privacy-safe.

Evidenza UI Debug/Release su dataset grande/current state:

- stato visibile **"Operazione in corso..."**;
- `ProgressView` visibile;
- pulsante **"Annulla"** visibile;
- nessun overlay globale bloccante;
- dopo cancel: **"Operazione annullata."**, summary volatile **"Controllo annullato."**, CTA **"Riprova"**;
- nessun gergo tecnico visibile nella card Release.

### Comandi e risultati finali

| Area | Comando / evidenza | Esito |
|---|---|---:|
| Git | `git status --short --branch`; `git rev-parse --short=12 HEAD` | PASS: branch `main`, commit `99d17787d604`, working tree dirty dichiarato. |
| Xcode list | `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS: target `iOSMerchandiseControl`, `iOSMerchandiseControlTests`; config `Debug`/`Release`; scheme `iOSMerchandiseControl`. |
| Dataset grande read-only | `sqlite3 .../default.store` conteggi aggregati | PASS: `ZPRODUCT=19698`, `ZSUPPLIER=61`, `ZPRODUCTCATEGORY=30`, `ZPRODUCTPRICE=39394`, `ZSYNCEVENTOUTBOXENTRY=0`; stessi conteggi dopo smoke. |
| Small dataset Debug | `xcodebuild ... -configuration Debug ... test -only-testing:...testTask075SmallDataset...` | PASS: **5 test**, 0 failure; xcresult `/tmp/task075-small-debug-dd/Logs/Test/Test-iOSMerchandiseControl-2026.05.08_11-52-35--0400.xcresult`. |
| Small dataset Release | `xcodebuild ... -configuration Release ... ENABLE_TESTABILITY=YES test -only-testing:...testTask075SmallDataset...` | PASS: **5 test**, 0 failure; xcresult `/tmp/task075-small-release-testable-dd/Logs/Test/Test-iOSMerchandiseControl-2026.05.08_11-57-28--0400.xcresult`. |
| Build Debug finale | `xcodebuild -quiet ... -configuration Debug ... -derivedDataPath /tmp/task075-final-debug-dd build` | PASS. |
| Build Release finale | `xcodebuild -quiet ... -configuration Release ... -derivedDataPath /tmp/task075-final-release-dd build` | PASS. |
| XCTest mirati finali | `xcodebuild ... -derivedDataPath /tmp/task075-final-tests-dd -parallel-testing-enabled NO test -only-testing:...` | PASS: **265 test**, 0 failure; xcresult `/tmp/task075-final-tests-dd/Logs/Test/Test-iOSMerchandiseControl-2026.05.08_11-59-26--0400.xcresult`. |
| Localizzazioni | `plutil -lint` IT/EN/ES/zh-Hans | PASS. |
| No-jargon manualSync | `rg` su `options.supabase.manualSync.*` per outbox/RPC/drain/SyncPreview/record_sync_event/payload/UUID/barcode/json/retryable | PASS: nessun match. |
| Diff whitespace | `git diff --check` | PASS. |

Nota Release test: il target unitario in configurazione Release pura ha `ENABLE_TESTABILITY=NO`, quindi i test con `@testable import` non sono eseguibili come unit test Release puro. Per la fixture S75-c e' stata usata configurazione **Release + `ENABLE_TESTABILITY=YES`**, mentre la build Release reale e' stata verificata separatamente senza override.

### Smoke dataset piccolo

| Run | Tipo dataset | Config | Esito | Nota |
|---|---|---|---:|---|
| S75-b | Fixture XCTest non distruttiva | Debug | PASS | Copre no pending, pending, running, completed, partial, error, cancel/retry, summary volatile, no doppia run, no mutazioni. |
| S75-c | Fixture XCTest non distruttiva | Release testable | PASS | Stessa matrice; nessun dato Simulator reale alterato. |

### Smoke dataset grande/current state

| Run | Config | Dataset | Esito | Evidenza |
|---|---|---|---:|---|
| S75-d Debug | Debug app reale | Current state grande: `19698` prodotti, `61` fornitori, `30` categorie, `39394` prezzi, outbox `0` | PARTIAL_EXPECTED | Avvio `12:01:08 -0400`; ancora running a `12:03:02 -0400`; UI responsive e feedback in corso visibile; cancel/retry/summary volatile PASS. Screenshot: `/tmp/task075_final_debug_large_cancelled_privacy_safe.png`. |
| S75-d Release | Release app reale | Stesso app container/dataset grande, senza reset dati | PARTIAL_EXPECTED | Avvio `12:04:26 -0400`; ancora running a `12:06:20 -0400`; UI responsive e feedback in corso visibile; cancel/retry/summary volatile PASS. Screenshot: `/tmp/task075_final_release_large_cancelled_privacy_safe.png`. |

Classificazione: **PARTIAL_EXPECTED accettato per closure**. Non e' PASS naturale per completamento entro tempo ragionevole, ma non e' FAIL: non ci sono crash, claim falsi, gergo tecnico, full sync, UI muta o recovery assente. Il comportamento osservato e' quello previsto dal rischio documentato per cataloghi grandi: running lungo ma controllabile e cancellabile.

### Check AGENTS finali

| Check | Stato | Evidenza |
|---|---:|---|
| Build compila (Xcode / BuildProject) | ✅ ESEGUITO | Debug PASS; Release PASS. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Warning MainActor/AppIntents gia' noti/preesistenti; nessun production code modificato. |
| Modifiche coerenti con il planning | ✅ ESEGUITO | Solo smoke read-only e test fixture; nessun full sync/guidedManual/apply/push/drain/cleanup/backend/Android. |
| Criteri di accettazione verificati | ✅ ESEGUITO | S75-b/S75-c PASS via fixture non distruttiva; S75-d Debug/Release `PARTIAL_EXPECTED` con recovery PASS; no-jargon/copy/static checks PASS. |

### Anti-scope confermato

- Nessun full sync.
- Nessun `guidedManual`; `supportsGuidedManualSync` non abilitato.
- Nessun apply/push/drain automatico o obbligatorio.
- Nessun reset/truncate/delete outbox reale; outbox resta `0`.
- Nessuna migration live Supabase, nessun `db push`, nessuna modifica SQL/RLS/RPC/backend.
- Nessuna modifica Android.
- Nessun token, URL sensibile, payload prodotto, barcode, UUID cliente o dato cliente stampato.

### Decisione finale

**Verdetto finale: DONE.**

Motivazione:

- Il blocker **S75-b/S75-c dataset piccolo** e' stato risolto con fixture/test-sandbox non distruttiva esplicitamente consentita dal follow-up utente.
- Il dataset grande/current state non e' spacciato per PASS naturale: resta **PARTIAL_EXPECTED**, con recovery/cancel/retry/summary volatile verificati in Debug e Release.
- Build Debug/Release e XCTest mirati finali sono PASS.
- Nessun perimetro vietato e' stato attraversato.

### Follow-up residui non bloccanti

- Ottimizzare o paginare ulteriormente la preview read-only su cataloghi molto grandi se si vuole trasformare `PARTIAL_EXPECTED` in PASS naturale entro una soglia UX definita.
- Aggiungere in un task separato eventuale telemetry/log privacy-safe di durata preview, senza esporre payload o dati cliente.

### Handoff finale

- **Stato finale TASK-075:** **DONE / Chiusura**.
- **Responsabile attuale:** nessuno / Workspace IDLE.
- **Nota:** non sono richiesti ulteriori fix per chiudere TASK-075; eventuali miglioramenti prestazionali sul catalogo grande sono follow-up separati.
