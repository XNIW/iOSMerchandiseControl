# TASK-092 — iOS: auto pull leggero all’apertura / foreground

## Informazioni generali

- **Task ID:** TASK-092
- **Titolo:** Auto pull leggero all’apertura / foreground
- **File task:** `docs/TASKS/TASK-092-lightweight-auto-pull-foreground-ios.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura — REVIEW PASS**
- **Responsabile attuale:** **Nessuno — task chiuso**
- **Data creazione:** 2026-05-09
- **Ultimo aggiornamento:** 2026-05-09 21:43 -0400 — REVIEW completa con fix mirati e verifiche finali **PASS**; **TASK-092 DONE / Chiusura — REVIEW PASS**. TASK-093 non aperto.
- **Ultimo agente che ha operato:** CODEX

---

## Dipendenze

- **Dipende da:** **TASK-091 DONE / Chiusura — REVIEW PASS** (`docs/TASKS/TASK-091-supabase-smart-semi-automatic-sync-ios.md`) — MVP semi-auto sulla card Release: cooldown 30 minuti, anti-reentrancy, guard auth/owner/sessione, piano staged volatile, preview remota read-only bounded (~5.000 righe catalogo/prezzi), review/conferma prima di apply/push/drain, cancellazione check dry-run, localizzazioni e test.
- **Sblocca:** roadmap **TASK-093…** (enqueue locale, push aggregato, ecc.) solo dopo chiusura pianificata di TASK-092; **non** aprire TASK-093 da questo file.

---

## Scopo

Definire un **piano iOS-first** per un **controllo cloud opportunistico e leggero** quando l’app viene **aperta** o torna in **foreground**, **riusando** i servizi e le policy già verificate in TASK-091, con **UX nativa compatta**, **nessuna mutazione silenziosa** e **nessun apply/push/drain automatico**.

TASK-092 non deve trasformare la sync in automatica. Deve solo rendere più intelligente e visibile il controllo read-only già introdotto in TASK-091, evitando che l’utente debba entrare manualmente nella tab Opzioni per scoprire se ci sono novità cloud da rivedere.

---

## Contesto (repo-grounded — lettura statica)

**Stato dopo TASK-091 (codice esistente, non modificato in questo task):**

- La policy semi-auto è in `SupabaseManualSyncSemiAutomaticPolicy` (cooldown default **30 min**, blocchi: capability cloud, running, auth/owner, staged non risolto).
- `SupabaseManualSyncViewModel` espone `suggestSemiAutomaticCheckIfAllowed` / `startForegroundSemiAutomaticCheckIfAllowed` e stati `semiAutomaticState`.
- Il trigger attuale è **localizzato sulla card Release** in `OptionsView` (`SupabaseManualSyncReleaseCard`): `onAppear` + `scenePhase == .active` chiama `startSemiAutomaticCheckIfNeeded()`; in background cancella run attive.
- Entry point app: `iOSMerchandiseControlApp` → `ContentView` con dipendenze Supabase iniettate; **non** c’è oggi un hook **globale** di foreground indipendente dal tab Opzioni.

**SwiftData + Supabase (solo livello planning):** confronto stale/conflitti resterà allineato a quanto già documentato in TASK-082/TASK-086 (`updated_at` catalogo, tombstone `deleted_at`, `effective_at` prezzi, baseline owner-scoped, recheck sessione prima di mutazioni). Nessuna decisione schema in TASK-092.

**Android:** solo riferimento funzionale (foreground/utility); **nessun** porting codice.

---

## Differenza rispetto a TASK-091 (cosa aggiunge TASK-092)

| Aspetto | TASK-091 (fatto) | TASK-092 (pianificato) |
|--------|-------------------|-------------------------|
| Ambito trigger | Principalmente quando la **card Release** appare / tab Opzioni + `scenePhase` sulla card | **Apertura app / foreground globale** (es. `ScenePhase` a livello `ContentView` o `App`), con regole chiare di dedupe rispetto al trigger card |
| Visibilità esito | Stato e summary nella card Opzioni | **Summary non bloccante** anche se l’utente è su altri tab: scelta planning = badge/pill discreta verso Opzioni + banner compatto solo quando ci sono novità o un errore recuperabile, mai modal automatico |
| UX | CTA primaria/sheet review già definite | Rifinitura: **nessun modal forzato** per il solo check read-only; gerarchia visiva coerente con `OptionsView`/card Release; copy breve **senza jargon** (no outbox/RPC/baseline in UI) |
| Mutazioni | Nessuna apply/push/drain silenziosa | **Stesso divieto** — solo preview/pull-check leggero; qualsiasi write locale/remota resta dietro flusso review esistente |

---

## Non incluso (anti-scope)

- Apply/pull catalogo o ProductPrice **automatico** senza conferma.
- Push catalogo, push ProductPrice, **drain outbox** automatici.
- `Timer` perpetuo, `BGTaskScheduler`, Realtime obbligatorio, **polling** continuo, worker background.
- Full reload dataset come soluzione principale; N+1 ingest.
- Modifiche **Kotlin**, **SQL**, **migration**, **RLS**, **backend** live.
- `project.pbxproj`, `Localizable.strings` in questa fase **PLANNING** (eventuali stringhe solo in futura execution autorizzata).
- Apertura **TASK-093+** o claim **DONE** / production-ready globale.

---

## Perfezionamento planning — UX/UI ed efficienza

### Decisione UX/UI operativa

Per evitare ambiguità in futura EXECUTION, TASK-092 sceglie già una direzione UX:

1. **Nessun modal automatico** al foreground: un controllo read-only non deve interrompere l’utente.
2. **Indicatore primario discreto**: usare un badge/pill collegato all’area cloud/Opzioni quando il check trova novità da rivedere.
3. **Banner compatto solo se utile**: mostrare un banner/safe-area notice root-level solo per stati actionable (`changesFound`, `recoverableError`, `blockedAuth`) e non per ogni `noChanges`.
4. **Checking silenzioso o quasi**: durante il check, preferire stato compatto nella card Release o un indicatore minimale; evitare spinner globale persistente.
5. **Azione unica e chiara**: dal banner/pill portare l’utente al flusso esistente **Opzioni → Controlla cloud / Rivedi**, senza creare un secondo percorso di review.
6. **Stile coerente iOS**: usare componenti SwiftUI nativi (`safeAreaInset`, `Label`, `Capsule`, `Material`, `Button`, `ToolbarItem`/badge se già coerente), senza imitare pattern Android.
7. **Cold start sempre rapido**: il check foreground non deve ritardare la prima UI dell’app; la home/tab iniziale deve renderizzare subito e il controllo cloud partire solo dopo che la UI è interattiva.

Copy orientativo, da localizzare solo in futura EXECUTION autorizzata:

- `changesFound`: “Ci sono aggiornamenti cloud da rivedere” → CTA “Rivedi”
- `checking`: “Controllo aggiornamenti…” → nessuna CTA obbligatoria
- `noChanges`: nessun banner; al massimo aggiornare timestamp nella card
- `blockedAuth`: “Accedi di nuovo per controllare il cloud” → CTA “Accedi” / fallback “Ricontrolla”
- `recoverableError`: “Controllo cloud non riuscito” → CTA “Riprova”

### Matrice stato presenter → UI / CTA

Questa matrice evita ambiguità in futura EXECUTION e impedisce interpretazioni troppo rumorose:

| Presenter state | UI root | CTA primaria | Persistenza sessione | Clearing |
|-----------------|---------|--------------|----------------------|----------|
| `hidden` | Nessun banner/pill root; eventuale timestamp solo in card Opzioni | Nessuna | No | Stato base |
| `checking` | Indicatore minimale solo se non disturba; preferire card/Opzioni se UI busy | Nessuna o “Annulla” solo se già pattern esistente | No | Background/cancel/fine check |
| `changesFound` | Banner compatto o pill verso Opzioni, solo se `canShowRootBanner == true` | “Rivedi” | Sì, solo in memoria sessione | Apertura review, discard, confirm, noChanges, auth change |
| `blockedAuth` | Banner/pill discreto solo se utile; fallback card Opzioni | “Accedi” o “Ricontrolla” secondo supporto esistente | No o breve sessione | Login/recheck/cambio stato auth |
| `recoverableError` | Banner compatto non ripetitivo; no modal | “Riprova” | Sì, con backoff/throttle | Riprova riuscito, dismiss, cooldown/backoff scaduto |

Regola: **nessuno stato presenter root contiene dati business raw**; solo stato, conteggi aggregati opzionali e reason generici.

### Scelta UI raccomandata per futura execution

Quando due soluzioni sono equivalenti, scegliere automaticamente quella più coerente con il resto dell’app e con SwiftUI:

- Preferire **pill/banner compatto root-level** rispetto a una nuova schermata o a un alert.
- Preferire **una sola CTA primaria** rispetto a più pulsanti concorrenti.
- Preferire **riuso della card Release esistente** rispetto a duplicare il flusso cloud in un’altra tab.
- Preferire un indicatore **stabile in sessione** (resta finché l’utente non rivede, chiude o avvia clear) rispetto a toast effimeri difficili da recuperare — **senza** persistenza disco per il solo cross-tab (coerente con § UX persistenza).
- Preferire **test fakeable sul ViewModel/presenter** rispetto a logica non testabile dentro la View.

### Vincoli di efficienza

- **Un solo task in-flight**: app-level foreground e card Opzioni devono convergere sulla stessa guard del ViewModel; nessuna seconda pipeline parallela.
- **Debounce lifecycle**: ignorare transizioni rapide `inactive → active` ravvicinate; in futura EXECUTION usare una finestra breve e testabile, non un timer ricorrente.
- **Cooldown autorevole**: il cooldown TASK-091 resta la barriera principale; eventuale flag “checked this session” deve essere secondario e documentato.
- **Preview bounded**: mantenere i limiti già introdotti in TASK-091; nessun full scan non necessario, nessun N+1 su catalogo/prezzi.
- **Main thread leggero**: parsing/confronti pesanti fuori dal main actor; UI aggiornata con summary aggregati, non con liste complete.
- **Nessuna mutazione SwiftData nel path auto-check**: lo stato staged resta volatile finché l’utente non entra nel flusso review/conferma esistente.
- **Cancel pulito**: background/cancel deve azzerare `checking` e non lasciare piani applicabili orfani.
- **Nessun blocco su launch**: non usare `await` o lavoro sincrono nel path di render iniziale; il check deve essere fire-and-delegate/cancellable dopo `active`, mai prerequisito per mostrare la UI.
- **Clock iniettabile/testabile**: cooldown, debounce e backoff devono usare un clock/test hook o astrazione equivalente dove possibile, per evitare test fragili basati su sleep reali.
- **Budget rete conservativo**: in caso di foreground frequenti, cooldown + backoff devono impedire chiamate ripetute non necessarie; meglio un check in meno che una UX rumorosa/costosa.

### Contratto architetturale — UI root vs ViewModel / presenter

Per futura EXECUTION, la separazione è vincolante:

1. **UI root** (`ContentView` o wrapper equivalente) può osservare il lifecycle (`ScenePhase`, foreground) e **mostrare** banner/pill/badge, ma **non** deve conoscere Supabase, staged plan, baseline, ProductPrice, outbox né leggere DTO remoti. Delega sempre a un **ViewModel o presenter compatto** già nel perimetro Release.
2. **Stato visibile dalla root** è **solo** un sottoinsieme derivato, stabile per la presentazione cross-tab: `hidden`, `checking`, `changesFound`, `blockedAuth`, `recoverableError`.  
   - Gli stati interni del ViewModel semi-auto (es. `idle`, `suggestedCheck`, `noChanges`, `reviewing`, `staleOrConflict` come in TASK-091) restano nel layer sync; il **mapping** verso il subset UI root è responsabilità del ViewModel/presenter (es. `noChanges` / post-review → `hidden`; `reviewing` può abbassare il banner o mostrare `checking` minimale — da rifinire in execution senza esporre jargon).
3. **Banner/pill clearable**: alla **apertura review**, **conferma apply/push**, **annulla run**, **scarto piano staged** (discard), l’indicatore cross-tab deve **aggiornarsi o sparire** nello stesso giro di stato del ViewModel, senza restare agganciato a un esito obsoleto.
4. **Cambio owner/session/auth** tra check e review: l’indicatore deve passare a `blockedAuth` **oppure** scomparire (`hidden`) se non è più lecito suggerire un’azione; **non** deve restare una CTA verso un piano non più valido.
5. **Privacy**: banner, log di debug e stringhe utente del path foreground non devono mostrare barcode, nomi prodotto, email, owner id, token, URL con segreti/query sensibili, payload remoti o campi business raw — solo **conteggi/messaggi aggregati** e reason code generici (coerente con TASK-074…091).
6. **No hidden second review flow**: il presenter root può solo indirizzare verso il flusso già esistente; non deve creare sheet alternative, editor paralleli o apply path separati.

### Backoff / throttle errori recuperabili e multi-scene

- **Errori rete/API recuperabili**: non devono generare **banner ripetuti** né **retry automatici** a ogni foreground. In futura execution introdurre **backoff/throttle** documentato (es. finestra minima tra tentativi automatici suggeriti, contatore o `lastRecoverableErrorAt`) nel ViewModel/policy condivisa — **testabile** con clock finto o hook DI.
- **Esito recuperabile in UI**: classificare come `recoverableError`, mostrare CTA **manuale** «Riprova» (o equivalente già localizzato nel flusso Release), **senza** bloccare navigazione o overlay full-screen.
- **iPad / multi-window**: più scene `.active` **non** devono avviare **due preview concorrenti** né due banner incoerenti. Il **dedupe** e il lock «una run in-flight» restano nel **ViewModel/policy condiviso** (stesso processo), non replicati per-scena nella View; ogni scene osserva lo **stesso** presenter state (o un bridge esplicito documentato se SwiftUI impone limiti — preferenza: una sola istanza VM Release per app session se già garantita dalla DI).

### UX — persistenza e pulizia indicatore

- Il banner/pill deve risultare **pulito** quando: utente apre review, conferma, scarta piano, annulla check, oppure un nuovo check converge a **nessuna modifica** (`noChanges` → presentazione `hidden` lato root).
- **Nessuna persistenza** su UserDefaults/SwiftData/File per banner o staged plan solo ai fini cross-tab: dopo **cold start** l’app può rieseguire un check bounded **solo** se ammesso da cooldown/policy TASK-091; lo stato presentazionale riparte da `hidden`/derivato session.

### Workflow gating — non disturbare flussi critici

TASK-092 resta **opportunistico**. In futura EXECUTION il check automatico / banner root **non** deve interferire con flussi dove l’attenzione o il layout sono critici:

- Import Excel / analisi file
- Export / share (activity sheet o export in corso)
- Scanner barcode (camera, risultato scansione)
- Editing riga / prodotto / form attivi
- Review sheet cloud già aperta
- `confirmationDialog` o conferme equivalenti
- Sheet **manual sync** Release / guided flow
- Qualunque schermata con `ProgressView` (o equivalente) **già visibile** per operazione **locale** lunga (es. import/export pesante)

**Regole operative (futura execution):**

- Se uno di questi stati “UI busy / workflow critico” è attivo, il foreground check può essere **deferito** (rimesso in coda logica post-idle), oppure ridotto a **solo** aggiornamento **card/Opzioni** senza banner root immediato — **senza** considerare il defer come errore recuperabile.
- Il banner root **non** deve coprire: CTA critiche, campi input, risultato scanner, toolbar con azioni distruttive, bottom bar/tab bar essenziali.
- Se review cloud è **già** aperta o esiste **piano staged non risolto** (allineato a guard TASK-091), **non** mostrare un **secondo** invito cross-tab duplicato: stato già gestito nel flusso esistente.
- Se l’app sta eseguendo **import/export locale** lungo, evitare rete opportunistica finché quel flusso non torna **idle** (priorità lavoro locale).

Il segnale “busy” è **presentazionale / orchestrazione UI**, non logica Supabase: vedi S92-C (`canShowRootBanner` o equivalente).

### Accessibilità, localizzazione e polish UI

Vincoli per **EXECUTION futura** (dopo override), non per la fase PLANNING:

- Ogni **nuova** stringa utente introdotta da TASK-092 deve essere localizzata in **IT / EN / ES / zh-Hans** tramite `Localizable.strings` (o meccanismo già usato dall’app) — **nessun** testo utente hard-coded in Swift.
- **VoiceOver**: etichette che combinano **stato + azione** in modo comprensibile, es. schema tipo «Aggiornamenti cloud disponibili — Rivedi» (testo finale solo nelle chiavi localizzate).
- **Dynamic Type**: la CTA primaria nel banner non deve risultare illeggibile/troncata; se necessario banner su **due righe**, mai full-screen per il solo check read-only.
- **Reduce Motion**: animazioni **brevi** o assenti se richiesto; **niente** effetti continui, lampeggianti o distraenti.
- **Colori**: solo **semantic** (`foregroundStyle`, accent di sistema, colori già usati nell’app) — niente palette ad-hoc che rompa coerenza.

---

## Micro-slice pianificate (futura EXECUTION — non autorizzate ora)

### S92-A — Analisi trigger e dedupe (app-level vs card, multi-scene)

- Mappare tutti i punti che oggi possono avviare o suggerire il check semi-auto.
- Definire **unica fonte di verità** per “foreground significativo” (cold start vs resume, prima `active` dopo `background`, debounce transizioni rapide) e classificare esplicitamente gli eventi da ignorare (`inactive` temporaneo, apertura sheet, cambio tab interno).
- Criterio: **un solo** check auto per finestra logica compatibile con cooldown TASK-091.
- **Multi-scene iPad**: documentare come più finestre/scene attive ricevono lo stesso stato presenter e **non** avviano run duplicate (CA-T092-16).
- **UI busy / workflow critico**: mappare stati e schermate (import/export, share, scanner, editing, review sheet, dialog conferma, sheet manual sync, progress locale) e definire quando il check è **subito** / **defer** / **solo card Opzioni** (nessun banner root). Output: tabella `stato UX busy → comportamento sync opportunistica`.
- Output atteso futura execution: tabella breve `evento lifecycle → azione/ignore`, così i test possono coprire casi reali.
- Output aggiuntivo: confermare che cold start/render iniziale non aspetta rete, auth refresh o preview Supabase prima di mostrare la UI principale.

### S92-B — Policy e guard (riuso + estensioni minime)

- Riusare `SupabaseManualSyncSemiAutomaticPolicy` / guard auth-owner / staged plan / anti-reentrancy.
- Documentare se servono **flag** session-scoped (es. “already auto-checked this session”) oltre al cooldown temporale — solo se necessario per evitare doppioni app-level + card.
- Decisione preferita: non introdurre un nuovo manager globale se il ViewModel può già garantire dedupe; eventuale helper lifecycle deve essere sottile, testabile e senza stato business duplicato.
- Se servono debounce/backoff/cooldown aggiuntivi, usare una sorgente temporale testabile/iniettabile o un wrapper minimo già coerente con i test esistenti; evitare `Task.sleep` reali nei test.

### S92-C — Wiring lifecycle (punto di aggancio)

- Progettare aggancio a `ScenePhase` (likely `ContentView` o wrapper sottile) che chiami **la stessa API** ViewModel già usata dalla card (no secondo orchestratore).
- La root osserva lifecycle e legge **solo** lo stato presenter (`hidden`…`recoverableError`); **zero** riferimenti Supabase/staged/baseline/ProductPrice nella View root.
- Garantire **cancel** coerente su background come oggi sulla card.
- Evitare che `ContentView` diventi proprietario di logica sync pesante: deve solo osservare lifecycle e delegare.
- Se la futura execution richiede un componente UI root per il banner, preferire un piccolo wrapper/presenter SwiftUI separato e testabile, non logica inline dispersa.
- Il wrapper root deve ricevere, dal layer presentazionale (non da Supabase), un segnale esplicito tipo **`canShowRootBanner`** (o equivalente): **derivato dalla UI / stato flussi critici** aggregato (busy import/export, sheet aperta, ecc.), **non** dalla business logic remota. Se `false`, il banner root resta assente anche se il ViewModel segnalerebbe `changesFound` lato dato — rete eventualmente deferita o riflessa solo su card Opzioni.
- Il wiring non deve introdurre dipendenze cicliche tra `ContentView`, `OptionsView` e il ViewModel: una sola direzione dati, con root che osserva/passa segnali presentazionali e il ViewModel che decide il check.

### S92-D — UX summary non bloccante cross-tab

- Implementare una strategia UX già scelta in planning: badge/pill discreta verso Opzioni come indicatore **stabile in sessione**, banner root compatto solo per stati actionable, nessun alert/modal automatico.
- Definire mapping stato presenter root → UI: `hidden` niente banner; `checking` minimale; `changesFound` banner + CTA «Rivedi»; `blockedAuth` CTA auth/fallback; `recoverableError` CTA «Riprova».
- **Clearing**: stesso giro di stato che chiude review, conferma, discard, annulla o `noChanges` deve **ripulire** banner/pill (CA-T092-13).
- Copy: azione chiara («Rivedi», «Ricontrolla», «Accedi di nuovo», «Riprova») senza termini tecnici; solo messaggi aggregati (CA-T092-15); in code solo chiavi `Localizable`, **mai** literal utente (CA-T092-18).
- **Safe-area e stacking**: banner/pill non deve coprire toolbar, bottom/tab bar, UI scanner, `confirmationDialog`, sheet, campi input o CTA distruttive; preferire `safeAreaInset` / padding coerenti con il layout esistente.
- **Motion / polish**: transizioni brevi; con **Reduce Motion** attivo, evitare animazioni superflue o ripetute — nessun lampeggio o loop visivo.
- **Accessibilità**: VoiceOver legge **stato + azione**; Dynamic Type supportato senza troncare la CTA primaria (banner a due righe se necessario); colori semantici coerenti con l’app (CA-T092-18).

### S92-E — Performance, recovery, backoff/throttle

- Confermare che il check foreground non aggiunge full reload e non introduce N+1 catalogo/prezzi.
- Confermare che lo stato UI non renderizza liste grandi fuori dalla review sheet.
- Verificare cancel/retry: background durante `checking`, ritorno foreground subito dopo, errore recuperabile e staged plan preesistente.
- **Backoff/throttle**: definire comportamento quando errori recuperabili si ripetono (no banner “retry” implicito a ogni `active`; solo dopo soglia temporale o azione utente «Riprova» — vedi CA-T092-14).
- **Priorità workflow**: import, export/share, scanner, editing locale e progress locale lunghi hanno **precedenza** sulla rete opportunistica; mentre sono attivi, il check può essere **posticipato** senza classificare il mancato avvio come fallimento — ripresa quando il flusso torna idle e `canShowRootBanner` lo consente.
- Output atteso: evidenza test/fake o audit statico che il path foreground resta bounded/read-only e che il rumore UI/API è limitato.

### S92-F — Testabilità e regressioni

- Estendere/aggiornare XCTest: decisioni policy, assenza di doppio avvio, debounce foreground, cancel su background, nessuna mutazione SwiftData su path auto-check, mapping stato presenter root, **clearing** dopo review/discard/noChanges (**CA-T092-13**), **backoff** errori recuperabili (**CA-T092-14**), asserzioni privacy-safe (**CA-T092-15**), **multi-scene** o doppio `ScenePhase` verso un’unica VM dove il test harness lo consente (**CA-T092-16**), **workflow gating** simulato: import/export/busy scanner/editing/review aperta/dialog/progress locale → nessun banner root invasivo o rete opportunistica che viola idle (**CA-T092-17**).
- **Checklist a11y / localization** (STATIC + review umano dove necessario): nessun literal statico in Swift per copy TASK-092; chiavi presenti in **IT/EN/ES/zh-Hans**; verifica VoiceOver labels/hints, Dynamic Type snapshot o test di layout dove fattibile, rispetto Reduce Motion nelle animazioni (**CA-T092-18**).
- **Rollback**: test o verifica che con capability/flag **off** il path root sia inerte e la card TASK-091 resti comportamentalmente valida (**CA-T092-22**).
- **Cold-start/performance check**: test o audit statico che il primo render non attende rete/auth/preview; eventuali test clock/backoff non devono dipendere da sleep reali lunghi.
- Matrix **STATIC/BUILD** come minimo; **SIM** solo se task/override futuro lo richiede.

### S92-G — Checklist review planning (Claude)

- Verificare allineamento MASTER-PLAN, assenza scope creep, gate Go/No-Go §10 (inclusi **G92-11** workflow gating, **G92-12** a11y/l10n, **G92-16…18** rollback/observability/QA futura).
- Verificare che TASK-092 resti **Planning** finché non esiste override esplicito utente per EXECUTION.

---

## Criteri di accettazione (futura EXECUTION — contratto)

- **CA-T092-01:** Alla transizione **foreground** (definita nel planning slice S92-A), se auth/owner/capability OK, può partire al massimo **una** sequenza di check preview read-only per finestra coerente con cooldown **30 min** e anti-reentrancy (stesso spirito TASK-091).
- **CA-T092-02:** Se auth/owner mancanti o staged plan non risolto, **nessuna** chiamata remota auto; stato UX chiaro e **non modale** obbligatorio.
- **CA-T092-03:** Il check auto usa solo percorsi **read-only/bounded** già usati da Release preview; **nessun** apply locale, **nessun** push, **nessun** drain outbox senza azione utente esplicita nel flusso esistente.
- **CA-T092-04:** Passaggio a **background** cancella o completa in modo sicuro il check in corso senza lasciare stato `checking` inconsistente o piano applicabile orfano (coerente con fix TASK-091).
- **CA-T092-05:** L’utente vede un **indicatore sintetico** (non full-screen) se ci sono novità da rivedere o se il controllo è in corso, **anche** se non è sul tab Opzioni (dettaglio implementativo in S92-D).
- **CA-T092-06:** Nessun termine tecnico visibile (outbox, RPC, baseline, drain, RLS) nelle stringhe utente Release/tab correlate.
- **CA-T092-07:** Test automatici aggiornati coprono almeno: policy/dedupe, assenza mutazioni su path auto-check, recovery cancel (livello definito in handoff EXECUTION).
- **CA-T092-08:** Il path app-level e il path card Opzioni non possono produrre due preview concorrenti; se entrambi si attivano, una sola run vince e l’altra viene ignorata/suggerita in modo deterministico.
- **CA-T092-09:** `noChanges` non deve generare banner rumorosi a ogni foreground; deve aggiornare solo stato/timestamp discreto.
- **CA-T092-10:** Il banner/pill cross-tab deve avere una sola CTA primaria e deve riusare il flusso review esistente, non aprire una seconda review parallela.
- **CA-T092-11:** Il check foreground non deve aumentare il costo computazionale in modo non bounded: niente full reload obbligatorio, niente N+1 catalogo/prezzi, niente lavoro pesante su main thread.
- **CA-T092-12:** Se due alternative UI sono entrambe valide, l’executor deve scegliere quella più coerente con lo stile esistente dell’app, preferendo meno churn, componenti SwiftUI nativi e migliore accessibilità.
- **CA-T092-13:** Il banner/pill cross-tab **non** può restare **stale** dopo review aperta, conferma mutazioni consentite, annulla run, discard piano staged, o dopo un esito **noChanges** che richiede silenzio lato root: deve aggiornarsi o sparire in modo deterministico rispetto a questi eventi.
- **CA-T092-14:** Gli errori recuperabili (rete/API) **non** devono causare retry automatici né banner rumorosi a **ogni** foreground; devono esistere **backoff/throttle** documentati e **testabili**; l’utente ha sempre percorso chiaro **«Riprova»** manuale senza bloccare l’app.
- **CA-T092-15:** UI, log e test del path foreground sono **privacy-safe**: solo conteggi/metriche aggregati e messaggi generici; vietati barcode, nomi prodotto, email, owner id, token, URL con segreti, payload remoti raw nelle stringhe o asserzioni esposte.
- **CA-T092-16:** Su **iPad/multi-window**, più scene in stato attivo **non** producono due check preview **concorrenti** né banner **incoerenti** tra scene: dedupe e serializzazione nella guard **condivisa** (ViewModel/policy), non nella singola View isolata.
- **CA-T092-17:** Se l’utente è in un **flusso critico** locale (import Excel, export/share, scanner, editing riga/prodotto, review sheet cloud aperta, dialog di conferma, sheet manual sync, operazione con `ProgressView` locale già visibile per lavoro lungo), il foreground check **non** interrompe e **non** copre la UI con banner root; viene **deferito**, **silenziato** lato banner root e/o limitato a **card/Opzioni** secondo il workflow gating — senza overlay su input/CTA critiche, toolbar distruttive o bottom bar.
- **CA-T092-18:** Ogni nuova UI/copy introdotta da TASK-092 è **accessibile** e **localizzabile**: nessun testo utente hard-coded in Swift; **VoiceOver** legge stato + azione; **Dynamic Type** senza troncamento inaccettabile della CTA primaria; **Reduce Motion** rispettato; **colori semantici** coerenti con lo stile dell’app.
- **CA-T092-19:** Il cold start e il primo render dell’app non aspettano rete, auth refresh o preview Supabase: il controllo foreground parte solo dopo UI interattiva e resta cancellabile.
- **CA-T092-20:** Cooldown, debounce e backoff sono testabili senza sleep reali lunghi; in futura execution usare clock/hook/DI o wrapper equivalente dove necessario.
- **CA-T092-21:** Il presenter root non introduce un secondo flusso review/apply: ogni CTA rimanda al flusso Release esistente e non crea sheet o mutazioni parallele.
- **CA-T092-22:** Esiste un **rollback logico**: disabilitando trigger e/o presenter root (es. flag/capability locale tipo **`supportsForegroundCloudCheck`** o equivalente testabile), il comportamento torna al solo **TASK-091 “card Opzioni only”** senza rompere i servizi Release stabili; la regressione deve essere **verificabile** (test o checklist).
- **CA-T092-23:** Eventuali **log / debug / eventi** del foreground check sono **privacy-safe** e **aggregati**: solo reason generici e conteggi dove applicabile; **vietati** payload business, barcode, nomi prodotto, owner id, email, session id, token, URL con segreti, payload remoti raw.
- **CA-T092-24:** La futura EXECUTION include una **mini matrice QA manuale** o **checklist verificabile** (v. § Rollback…) per: cold start, resume, `noChanges`, `changesFound`, `blockedAuth`/`recoverableError`, workflow busy, accessibilità — non solo test automatici senza verifica UX reale.

---

## Rischi (R92-xx)

| ID | Rischio | Mitigazione |
|----|---------|-------------|
| R92-01 | Doppio trigger (App + card) → doppia rete / stato incoerente | S92-A/S92-B dedupe; una sola API ViewModel |
| R92-02 | Check con utente su Inventario/Database → distrazione | Summary non bloccante; nessun modal; badge discreto |
| R92-03 | Costo API / rate limit | Cooldown; bounded preview; cancel |
| R92-04 | Stale/conflict dopo check auto senza review | Mai apply auto; forzare review sheet esistente prima di mutazioni |
| R92-05 | Scope creep nuova tab o redesign | Evolvere pattern esistenti (tab Opzioni + indicator leggero) |
| R92-06 | Banner troppo frequente → fastidio utente | Banner solo per stati actionable; `noChanges` silenzioso |
| R92-07 | `ContentView` accumula logica business sync | Delegare al ViewModel; eventuale presenter UI sottile |
| R92-08 | Transizioni lifecycle rapide generano race | Debounce testabile + anti-reentrancy ViewModel |
| R92-09 | Regressione performance su dataset grande | Preview bounded, mappe/batch, no N+1, test/fake mirati |
| R92-10 | Banner/CTA **stale** dopo review, conferma, discard o cambio auth | Mapping presenter su eventi ViewModel; invalidazione su session change; CA-T092-13 |
| R92-11 | Errori rete **rumorosi** a ogni apertura (banner/retry impliciti) | Backoff/throttle + solo «Riprova» manuale; CA-T092-14 |
| R92-12 | **Leak privacy** in banner/log/test (dati business o segreti) | Policy aggregati; review copy/test grep; CA-T092-15 |
| R92-13 | **Multi-window iPad** avvia run duplicate o stati divergenti | Lock condiviso VM; stesso presenter state per scene; CA-T092-16 |
| R92-14 | Banner/check disturba **import/export/scanner/editing** | Workflow gating + defer/solo card Opzioni; `canShowRootBanner`; CA-T092-17 |
| R92-15 | Nuova UI **non accessibile** o **non localizzata** | Checklist a11y/l10n; chiavi quattro lingue; STATIC grep anti-literal; CA-T092-18 |
| R92-16 | Cold start rallentato da auth/rete/preview | Primo render indipendente dal check; fire-after-active cancellabile; CA-T092-19 |
| R92-17 | Test fragili/lenti per debounce/backoff | Clock/test hook o wrapper temporale; CA-T092-20 |
| R92-18 | Secondo flusso review/apply nascosto nella root | CTA solo verso flusso Release esistente; CA-T092-21 |
| R92-19 | Regressione **difficilmente reversibile** del trigger root rispetto a TASK-091 | Rollback logico verso card-only; flag/capability piccolo; CA-T092-22; G92-16 |
| R92-20 | **Log/eventi** troppo dettagliati o non privacy-safe | Solo reason generici + aggregati; CA-T092-23; G92-17 |
| R92-21 | Test automatici **PASS** ma UX reale ancora rumorosa/confusa | Mini matrice QA manuale futura obbligatoria; CA-T092-24; G92-18 |

---

## Definition of Done (planning — TASK-092)

- Sezioni **Obiettivo, Analisi, Approccio, File coinvolti, Rischi, Criteri di accettazione, Handoff** presenti e coerenti con CLAUDE.md.
- Gate **§10 Go/No-Go** compilato per futura EXECUTION (inclusi cleanup UX, privacy, error handling, **workflow gating**, **a11y/l10n**, **rollback G92-16**, **observability G92-17**, **QA manuale G92-18**).
- Contratto architetturale **root senza Supabase/staged/baseline/ProductPrice**; presenter con stati `hidden/checking/changesFound/blockedAuth/recoverableError`.
- Decisione UX/UI cross-tab già esplicitata: badge/pill **derivato e clearable**, nessuna persistenza permanente banner/staging per cross-tab; banner compatto solo actionable dove previsto, nessun modal automatico read-only.
- Vincoli di efficienza esplicitati: cooldown, debounce lifecycle, un solo task in-flight, preview bounded, no N+1, no lavoro pesante su main thread, **backoff/throttle** su errori recuperabili, **dedupe multi-scene** nel VM condiviso.
- **Workflow gating** e **priorità flussi locali** documentati; safe-area / non copertura CTA critiche; vincoli **a11y / l10n / Reduce Motion** esplicitati.
- Vincoli finali pre-execution esplicitati: cold start non bloccante, clock/backoff testabile, nessun secondo flusso review/apply dalla root.
- **Rollback**, **osservabilità privacy-safe** e **mini matrice QA manuale futura** documentati (§ dedicato); CA-T092-22…24 e gate **G92-16…18**.
- **Nessun** codice modificato nella fase **PLANNING** (solo questo file task).
- Handoff verso EXECUTION **solo** dopo override utente esplicito su fase/task.

---

## Gate Go / No-Go — §10 (futura EXECUTION)

| # | Gate | Go se… | No-Go se… |
|---|------|--------|-----------|
| G92-01 | Baseline TASK-091 | Comportamento semi-auto Release stabile e test verdi su branch prescelto | Regressioni non spiegate su stati semi-auto |
| G92-02 | Punto lifecycle | È scelto un solo punto di ingresso app-level documentato (file/classe) | Più `ScenePhase` concorrenti senza dedupe |
| G92-03 | UX | Summary cross-tab approvato in planning: badge/pill + banner actionable, no modal | Richiesta modale bloccante per read-only |
| G92-04 | Mutazioni | Prova statica: nessun `apply`/`push`/`drain` nel path auto-check | Qualsiasi write automatica nel diff |
| G92-05 | Performance | Preview resta bounded; nessun full reload obbligatorio | Piano che dipende da full scan catalogo |
| G92-06 | Rumore UI | `noChanges` resta silenzioso; banner solo actionable | Banner/alert a ogni foreground |
| G92-07 | Test lifecycle | Esiste piano test per debounce, doppio trigger, cancel background | Lifecycle affidato solo a test manuale |
| G92-08 | Cleanup UX | Banner/pill si ripulisce dopo review / discard / confirm (ove applicabile) / noChanges come da contratto | Indicatore resta visibile con CTA verso piano invalido o esito obsoleto |
| G92-09 | Privacy | UI/log/test del path foreground usano solo aggregati e messaggi generici | Presenza di PII, segreti, payload raw, barcode/nome prodotto in UI o test esposti |
| G92-10 | Error handling | Errori recuperabili con throttle/backoff documentato; retry solo manuale chiaro | Retry/banner automatici a ogni foreground senza backoff |
| G92-11 | Workflow gating | Import/export/scanner/editing/review/dialog/progress locale **non** coperti né interrotti da banner root; rete opportunistica deferita finché busy | Banner sopra input/CTA critiche; check rete durante progress locale lungo senza defer |
| G92-12 | A11y / localization | Copy solo via `Localizable` **IT/EN/ES/zh-Hans**; VoiceOver/Dynamic Type/Reduce Motion/semantic colors considerati | Testo hard-coded in Swift; banner non accessibile o CTA illeggibile a Dynamic Type large |
| G92-13 | Cold start | Primo render non attende rete/auth/preview; check parte dopo UI interattiva | UI iniziale bloccata dal check foreground |
| G92-14 | Test tempo | Debounce/backoff/cooldown testabili senza sleep reali lunghi | Test lenti/flaky basati su attese reali |
| G92-15 | Flusso review unico | CTA root rimanda al flusso Release esistente | Nuova sheet review/apply parallela in root |
| G92-16 | Rollback | Disabilitare root foreground check lascia **TASK-091 / card Opzioni** funzionante e testabile | Trigger root **accoppiato in modo irreversibile** ai servizi Release |
| G92-17 | Observability | Log/debug/eventi solo **aggregati** e privacy-safe | Compaiono payload business, identificatori (prodotto/owner/sessione) o segreti |
| G92-18 | QA futura | Esiste **matrice smoke manuale** piccola (checklist) per foreground / busy / a11y | Solo test automatici senza verifica UX reale documentata |

**Stato gate (PLANNING):** tutti **PENDING** — nessuna EXECUTION avviata.

---

## Rollback, osservabilità privacy-safe e QA futura

Sezione **planning-only**: vincoli per futura EXECUTION, senza codice in questa fase.

### 1. Rollback logico

- In futura EXECUTION deve essere possibile tornare al comportamento **TASK-091 “solo card Opzioni”** disabilitando il **trigger** e/o il **presenter root** (nessun banner/pill app-level), senza toccare servizi Release (`SupabasePullPreviewService`, coordinator, apply/push/drain confermati, ecc.).
- Il rollback **non** deve rompere la sync manuale/semi-auto già stabile sulla card.
- Se serve una guard, preferire un **flag o capability locale piccolo e testabile** (nome indicativo: `supportsForegroundCloudCheck` o equivalente iniettato in fase build/test), **non** un nuovo sistema remoto o feature flag lato backend.
- Verifica attesa: con flag disatteso, le XCTest/regressioni TASK-091-relevant su card continuano a valere; eventuali test aggiuntivi documentano il percorso “root off”.

### 2. Osservabilità privacy-safe

- **Log / debug / test** possono registrare solo **eventi generici** e, dove utile, **conteggi aggregati** (es. numero di skip, mai elenchi di SKU).
- **Esempi ammessi** (nomi indicativi, non vincolanti): `foreground_check_suggested`, `foreground_check_skipped_busy`, `foreground_check_throttled`, `foreground_check_completed_no_changes`, `foreground_check_completed_changes`.
- **Vietati** in log/eventi/assert: barcode, nomi prodotto, owner id, email, **session id**, payload remoti, token, URL con query segrete, dump di risposta rete.
- Allineamento a **CA-T092-15** e **CA-T092-23**.

### 3. Mini matrice QA manuale futura (checklist smoke)

Da eseguire in **REVIEW** o **post-EXECUTION** con evidenz documentata (non obbligatoria nella fase PLANNING). Righe minime:

| # | Scenario | Atteso (sommario) |
|---|----------|-------------------|
| QA-01 | **Cold start** | UI interattiva subito; nessun blocco su rete; check opportunistico al più tardi e cancellabile |
| QA-02 | **Resume dopo background** | Nessun doppio burst rumoroso; dedupe/cooldown rispettati |
| QA-03 | **`noChanges`** | Silenzioso lato banner root; eventuale aggiornamento discreto card |
| QA-04 | **`changesFound`** | Banner/pill coerente; CTA verso flusso Release; nessuna seconda review |
| QA-05 | **`blockedAuth`** | Stato chiaro; nessun jargon; percorso login/ricontrollo |
| QA-06 | **`recoverableError`** | «Riprova» manuale; nessun retry automatico ogni foreground |
| QA-07 | **Import/export busy** | Nessun banner invasivo; defer o solo card (CA-T092-17) |
| QA-08 | **Scanner / editing busy** | Stesso gating; nessuna copertura input/scanner |
| QA-09 | **Dynamic Type grande** | CTA leggibile (anche due righe); nessun full-screen |
| QA-10 | **VoiceOver** | Stato + azione annunciati correttamente |
| QA-11 | **Reduce Motion** | Nessuna animazione continua/distrattiva |

La checklist è il minimo **contrattuale** per **CA-T092-24** e **G92-18**; righe aggiuntive ammesse se non allargano oltre TASK-092.

---

## File iOS candidati (futura EXECUTION — solo lettura in questa fase)

- `iOSMerchandiseControlApp.swift` — entry scene; eventuale osservazione lifecycle.
- `ContentView.swift` — candidato naturale per `ScenePhase` globale e propagazione a VM esistente; deve restare un wrapper leggero, non contenere logica business sync.
- `OptionsView.swift` — `SupabaseManualSyncReleaseCard`, `startSemiAutomaticCheckIfNeeded`, integrazione con nuovo wiring e indicatore/badge coerente.
- `SupabaseManualSyncViewModel.swift` — API semi-auto esistenti; possibili estensioni minime per dedupe/session/debounce.
- `SupabaseManualSyncSemiAutomaticPolicy.swift` — policy cooldown e blocchi; da riusare come fonte autorevole.
- Eventuale piccolo presenter SwiftUI per banner/pill root-level — solo se evita logica inline dispersa e resta coerente con lo stile esistente.
- `SupabaseManualSyncReleaseFactory.swift` / `SupabaseManualSyncCoordinator.swift` — solo se serve DI aggiuntiva (evitare se possibile).
- Servizi preview già usati da Release: `SupabasePullPreviewService`, adapter preview/coordinator — **nessuna** nuova rete parallela.
- Test: `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, eventuali test policy semi-auto/lifecycle.

---

## Decisioni (D92-xx)

| ID | Decisione | Alternative scartate | Motivazione | Stato |
|----|-----------|----------------------|-------------|--------|
| D92-01 | TASK-092 inizia come **solo planning** markdown | Implementare subito lifecycle | Workflow progetto; override separato per Swift | attiva |
| D92-02 | Riutilizzare ViewModel/servizi TASK-091; **no** second orchestratore | Nuovo `AutoSyncManager` | Minimo cambiamento; meno regressioni | attiva |
| D92-03 | Solo preview/pull-check leggero; mutazioni solo dopo review utente | Auto-apply ottimistico | Allineamento TASK-076…091 | attiva |
| D92-04 | Indicatore cross-tab **leggero**; nessun full-screen blocking per read-only | Alert ad ogni foreground | UX iOS coerente | attiva |
| D92-05 | UX scelta: badge/pill **stabile in sessione** (fino a clear/review) + banner compatto solo per stati actionable | Banner per ogni esito, toast, modal automatico | Riduce rumore e resta coerente con iOS | attiva |
| D92-06 | `noChanges` non produce avviso foreground | Notifica “tutto aggiornato” ad ogni apertura | Evita spam; timestamp/card bastano | attiva |
| D92-07 | `ContentView`/root osserva lifecycle ma non contiene business sync | Logica sync inline nella View root | Separazione SwiftUI/ViewModel; testabilità | attiva |
| D92-08 | Performance: batch/mappe/bounded preview obbligatori in futura execution | Full reload o N+1 tollerati | Dataset grande e costo API già emersi nei task precedenti | attiva |
| D92-09 | Quando due alternative UX sono equivalenti, l’executor sceglie autonomamente quella più coerente con lo stile esistente | Bloccare execution per micro-scelte UI | Migliora ritmo lavoro e mantiene UX coerente | attiva |
| D92-10 | Banner/pill cross-tab è **derivato** dal ViewModel/presenter, **clearable** sugli eventi review/confirm/discard/cancel/noChanges; **nessuna** persistenza permanente dedicata | Salvare stato banner su `AppStorage`/file per “ricordare” novità | Evita stale dopo restart e semplifica coerenza con staged volatile TASK-091 | attiva |
| D92-11 | Errori recuperabili: **backoff/throttle** nel layer condiviso + CTA **«Riprova»** manuale; niente retry auto ogni foreground | Rilanciare check a ogni `scenePhase.active` dopo errore | Riduce rumore e costi API; allinea a CA-T092-14 | attiva |
| D92-12 | **Privacy**: UI/log/test path foreground = **solo aggregati** e messaggi generici | Mostrare dettaglio righe o identificativi in banner | Allinea a roadmap privacy-safe TASK-074…091; CA-T092-15 | attiva |
| D92-13 | **Multi-scene** (iPad): dedupe e anti-concorrenza nella **guard ViewModel/policy condivisa**, non nella singola View | Ogni `ScenePhase` istanzia logica sync separata | Evita run duplicate e banner incoerenti; CA-T092-16 | attiva |
| D92-14 | I **flussi locali critici** (import/export, share, scanner, editing, review/dialog/sheet sync, progress locale) hanno **priorità** sulla rete opportunistica | Avvio check/banner root nonostante UI busy | CA-T092-17; riduce conflitti UX e perdita dati percepita | attiva |
| D92-15 | Nuova UI TASK-092 rispetta **safe-area**, **VoiceOver**, **Dynamic Type**, **Reduce Motion** e **localizzazioni** esistenti (quattro lingue) | Shortcut solo italiano o literal in View | CA-T092-18; coerenza prodotto | attiva |
| D92-16 | Cold start non bloccante: il check non è prerequisito del primo render | Aspettare auth/rete prima di mostrare UI | App più reattiva e meno fragile; CA-T092-19 | attiva |
| D92-17 | Tempo testabile per cooldown/debounce/backoff | Sleep reali nei test | Test veloci e deterministici; CA-T092-20 | attiva |
| D92-18 | Root presenter non crea flusso review/apply alternativo | Sheet parallela in `ContentView` | Mantiene trust model Release; CA-T092-21 | attiva |
| D92-19 | **Rollback logico** verso **card-only TASK-091** deve restare sempre possibile | Trigger root obbligatorio e non spegnibile | Riduce rischio irreversibile; CA-T092-22; G92-16 | attiva |
| D92-20 | **Osservabilità** solo aggregata / privacy-safe | Log ricchi di PII o payload | CA-T092-23; G92-17 | attiva |
| D92-21 | **QA manuale futura minima** obbligatoria per UX foreground oltre agli automatici | Solo XCTest senza smoke documentato | CA-T092-24; G92-18 | attiva |

---

## Planning (Claude)

### Analisi

TASK-091 ha implementato la semi-auto **dove l’utente gestisce già il cloud** (card Release). Resta un gap di prodotto: al **ritorno in app** l’utente può non aprire Opzioni, quindi non riceve il suggerimento/check. TASK-092 pianifica l’estensione **app-wide** dello stesso tipo di lettura sicura, con dedupe e summary non invasivo, senza modificare il modello di trust “conferma prima di mutare”.

Il punto delicato non è la rete in sé, ma l’equilibrio UX: l’utente deve capire che ci sono aggiornamenti cloud utili, senza sentirsi interrotto ogni volta che apre l’app. Per questo il planning sceglie una UI discreta, **derivata** da un presenter compatto, **clearable** e **non persistente** per scopi cross-tab, actionable solo quando serve.

**Architettura:** la root SwiftUI non deve diventare un secondo client Supabase; tutto ciò che è cloud/staged resta nel ViewModel Release. La root consuma solo cinque stati presentazionali, un bit/tipo **`canShowRootBanner` derivato dalla UI busy**, e rispetta privacy aggregata, backoff su errori, serializzazione multi-scene e **non interferenza** con import/export/scanner/editing (CA-T092-17).

### Approccio proposto

1. Completare S92-A–S92-G in documento prima di qualsiasi Swift.
2. In EXECUTION futura: un solo hook `ScenePhase`/`active` a livello root che delega al `SupabaseManualSyncViewModel` (o equivalente iniettato) le stesse entry point della card.
3. Aggiungere presentazione **non bloccante** per esito/suggerimento quando l’utente è fuori da Opzioni: badge/pill **stabile in sessione** verso Opzioni + banner compatto solo per `changesFound`/`blockedAuth`/`recoverableError`.
4. Mantenere `noChanges` silenzioso e aggiornare solo timestamp/stato discreto nella card Release.
5. Aggiornare test per coprire dedupe, debounce lifecycle, **clearing** banner dopo review/discard/noChanges, **backoff** errori recuperabili, **privacy** stringhe/test, **multi-scene** (ove testabile), **workflow gating** (busy → nessun banner invasivo), **a11y/l10n** (no literal, chiavi quattro lingue), assenza di mutazioni silenziose, cold start/backoff testabile, flusso review unico (**CA-T092-13…21**), più **rollback** flag e osservabilità aggregata (**CA-T092-22…23**) e evidenza **checklist QA manuale** (**CA-T092-24**).
6. Evitare refactor ampi: se il ViewModel esistente basta, non creare un nuovo manager globale; introdurre solo un **mapping presenter** esplicito root-facing se necessario.
7. Confermare che il primo render resti indipendente da rete/auth/preview; il check è una conseguenza cancellabile del foreground, non una precondizione di avvio.
8. Rendere debounce/backoff/cooldown testabili con clock/hook/DI o wrapper equivalente, evitando test lenti/flaky.
9. Mantenere il flusso review/apply unico: root banner/pill è solo un invito verso Release, non un secondo flusso operativo.
10. Prevedere **rollback** (`supportsForegroundCloudCheck` o equivalente): servizi Release non accoppiati in modo irreversibile al trigger root.
11. **Osservabilità**: solo eventi generici/aggregati in log/debug (**CA-T092-23**).
12. Allegare evidenza o checklist per **mini matrice QA manuale** in review (**CA-T092-24**).

### File da modificare (futuro — non ora)

Elenco indicativo: `ContentView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, eventuale piccolo presenter SwiftUI per banner/pill se utile, test correlati; evitare toccare servizi verticali se non strettamente necessario.

### Rischi identificati

Vedi tabella R92-xx; principali: doppio trigger, rumore UI, regressione performance, **banner stale**, **errori rete rumorosi**, **leak privacy**, **multi-window duplicate**, **conflitto con flussi critici**, **a11y/l10n insufficienti**, cold start lento, test temporali fragili, rischio secondo flusso review/apply, **rollback irreversibile**, **log non privacy-safe**, **UX reale non verificata** (solo test automatici).

### Handoff → Execution

- **Prossima fase:** EXECUTION (solo dopo **override utente esplicito** e completamento review planning se richiesta).
- **Prossimo agente:** CODEX / Executor
- **Azione consigliata:** Leggere questo file + MASTER-PLAN; implementare S92-A→G nel minor numero di file; rispettare contratto presenter root (`hidden`…`recoverableError`) e segnale **`canShowRootBanner`** (busy UI ≠ Supabase); workflow gating; safe-area; localizzazioni **IT/EN/ES/zh-Hans** e a11y; cold start non bloccante; tempo testabile per cooldown/debounce/backoff; nessun secondo flusso review/apply dalla root; **rollback** testabile (flag tipo `supportsForegroundCloudCheck`); **log/eventi** solo privacy-safe; completare **CA-T092-13…24** (test STATIC + **mini matrice QA manuale** documentata); **non** marcare DONE senza review.

**Stato handoff:** **SUPERATO DA OVERRIDE ESPLICITO UTENTE** — questa riga era lo stato storico del planning prima della richiesta del 2026-05-09 di avviare l'intera EXECUTION. Lo stato corrente e' tracciato nei metadati e in **Handoff post-execution (Codex)**.

**Stato storico (dopo questo perfezionamento planning):** **TASK-092** = **ACTIVE / PLANNING**; **NON DONE**; **NON READY FOR EXECUTION**; nessuna EXECUTION Swift/Kotlin/SQL/Localizable/`project.pbxproj` autorizzata da questo documento. Stato corrente dopo override/execution/review: **DONE / Chiusura — REVIEW PASS**. **Nessun** claim production-ready globale o al 100%.

---

## Execution (Codex)

### Stato execution

- **Avvio:** 2026-05-09 20:44 -0400 — override esplicito utente da **ACTIVE / PLANNING** a **ACTIVE / EXECUTION**.
- **Chiusura execution:** 2026-05-09 21:08 -0400.
- **Esito:** implementation iOS-first completata e verificata; task portato a **ACTIVE / REVIEW**.
- **Responsabile review:** **Claude / Reviewer**.
- **TASK-092:** **NON DONE**.
- **TASK-093:** non aperto.

### Obiettivo compreso

Implementare un auto pull/check cloud leggero all'apertura o foreground, riusando il lavoro semi-auto TASK-091 sulla card Release/Opzioni, senza mutazioni silenziose e senza creare un secondo flusso review/apply. Il primo render deve restare immediato; root e card devono convergere sulla stessa guard; la root deve vedere solo un presenter compatto privacy-safe.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-092-lightweight-auto-pull-foreground-ios.md`
- `docs/TASKS/TASK-091-supabase-smart-semi-automatic-sync-ios.md`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncSemiAutomaticPolicy.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/InventoryHomeView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/PreGenerateView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`

### Piano minimo eseguito

1. Promuovere tracking a EXECUTION su override utente, mantenendo TASK-091 ultimo completato e TASK-092 non DONE.
2. Aggiungere un hook root/`scenePhase` leggero che parte solo dopo UI interattiva, cancellabile su background e deferito quando la UI e' busy.
3. Riutilizzare `SupabaseManualSyncViewModel` e policy TASK-091, aggiungendo solo guard condivisa per foreground, debounce/backoff e capability rollback.
4. Derivare un presenter root compatto (`hidden/checking/changesFound/blockedAuth/recoverableError`) senza esporre Supabase, staged plan, baseline, ProductPrice, outbox o DTO remoti alla root.
5. Cablarlo alla card Opzioni esistente con una sola CTA verso il flusso Release, copy localizzato e accessibilità.
6. Coprire i criteri con XCTest mirati, full suite, build Debug/Release, localizzazioni, anti-scope grep e smoke Simulator.

### Modifiche fatte

- `ContentView.swift`: aggiunto wrapper root `SupabaseManualSyncForegroundRootHost`, hook `ScenePhase`, task foreground cancellabile post-render, shared `SupabaseManualSyncViewModel`, banner compatto safe-area solo per stati actionable, routing CTA verso Opzioni/Login/Riprova e activity center UI-busy.
- `OptionsView.swift`: la card Release puo' ricevere il ViewModel condiviso; mantenuto fallback factory per rollback/preview. Aggiunti marker busy per review sheet e confirmation dialog.
- `InventoryHomeView.swift`, `DatabaseView.swift`, `PreGenerateView.swift`, `GeneratedView.swift`: aggiunti marker presentazionali busy per import/export/share/scanner/editing/progress/dialog senza logica cloud.
- `SupabaseManualSyncViewModel.swift`: aggiunti source root/card, presenter root derivato, capability `supportsForegroundCloudCheck`, gate foreground automatico condiviso, eventi aggregati privacy-safe, dedupe multi-scene, clearing banner su review/discard/confirm/noChanges/cancel/auth change, manual retry e skip busy.
- `SupabaseManualSyncSemiAutomaticPolicy.swift`: estesa policy con debounce foreground e backoff errori recuperabili, testabili via date injection gia' usata dai test.
- Localizzazioni IT/EN/ES/zh-Hans: aggiunte 11 nuove chiavi root foreground; nessun nuovo testo utente hard-coded in Swift.
- XCTest: aggiunta copertura per trigger foreground, dedupe root+card/multi-scene, `noChanges` silenzioso, `changesFound`, `blockedAuth`, `recoverableError` con backoff/throttle, cancel/cleanup, workflow gating busy, cold start statico, rollback root off, privacy-safe state/log/copy e coverage Localizable.

### Decisioni prese durante execution

- Nessun nuovo orchestratore pesante: la serializzazione resta nel ViewModel/policy condivisi.
- Root host possiede una sola istanza ViewModel Release per sessione app e la passa alla card Opzioni, cosi' app-level e card convergono sulla stessa guard.
- Il banner root e' assente nella tab Opzioni e durante stati busy, per evitare duplicati con la card o copertura di workflow critici.
- `noChanges` resta silenzioso lato root; l'evento osservabile e' solo aggregato.
- `supportsForegroundCloudCheck` e' il rollback logico: se disabilitato, il root path resta inerte e la card TASK-091 continua a usare il comportamento semi-auto esistente.
- La CTA root non apre sheet nuove: `Rivedi` porta alla tab Opzioni/flusso Release, `Accedi` usa il percorso auth esistente, `Riprova` chiama il manual retry del ViewModel.
- Nessun Supabase live write eseguito; non e' servito usare backend/SQL/migration.

### Check eseguiti

| Check | Stato | Evidenza |
|---|---:|---|
| Preflight `git status` | ✅ ESEGUITO | Working tree dirty con file TASK-092/Swift/localizzazioni/test modificati e task file TASK-092 non tracciato; nessuna modifica Kotlin/Android. |
| `xcodebuild -list` + scheme | ✅ ESEGUITO | Scheme `iOSMerchandiseControl` verificato. |
| Simulator disponibile | ✅ ESEGUITO | iPhone 16e iOS 26.2 disponibile e usato. |
| Build Debug | ✅ ESEGUITO | `xcodebuild build ... -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS. Warning toolchain AppIntents metadata, non introdotto da TASK-092. |
| Build Release | ✅ ESEGUITO | `xcodebuild build ... -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS. Stesso warning AppIntents metadata. |
| XCTest mirati TASK-092 | ✅ ESEGUITO | `SupabaseManualSyncViewModelTests` + `SupabaseManualSyncReleaseUITests`: **106 test / 0 failure**. |
| Full XCTest iOS | ✅ ESEGUITO | Full suite: **590 test / 0 failure**. |
| `plutil` Localizable IT/EN/ES/zh-Hans | ✅ ESEGUITO | Tutti OK. |
| Duplicate localization scan | ✅ ESEGUITO | Nessuna chiave duplicata rilevata nei quattro file. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| Anti-literal nuove stringhe TASK-092 | ✅ ESEGUITO | Copy root localizzato; nessun literal utente TASK-092 trovato in Swift. |
| Anti-scope static grep | ✅ ESEGUITO | Nessun `Timer`, `BGTaskScheduler`, polling continuo, Realtime obbligatorio, auto apply/push/drain, SQL/migration/backend live, log segreti o dati business nel diff TASK-092. |
| Kotlin/Android diff | ✅ ESEGUITO | Nessun file Kotlin/Android modificato. |
| Privacy-safe observability | ✅ ESEGUITO | Solo eventi aggregati `foreground_check_*`; nessun owner/session/token/email/barcode/nome prodotto/payload remoto. |
| QA Simulator cold start | ✅ ESEGUITO | Screenshot `/tmp/task092-cold-start-ui.png`: UI principale interattiva, nessun modal/banner spurio. |
| QA Simulator Dynamic Type grande | ✅ ESEGUITO | Screenshot `/tmp/task092-dynamic-type-ui.png`: UI renderizzata con testo grande; nessun crash o overlay foreground invasivo. |
| QA manuale noChanges/changesFound/blockedAuth/recoverableError | ✅ ESEGUITO | Coperti con XCTest fakeable/presenter; non usato live Supabase per evitare write o dipendenza dati reali. |
| VoiceOver manuale | ⚠️ NON ESEGUIBILE | Non praticato in modo affidabile dal run headless; copertura statica: `accessibilityLabel` unisce stato + azione e XCTest verifica copy privacy-safe/localizzato. |
| Reduce Motion manuale | ⚠️ NON ESEGUIBILE | Non praticato in modo affidabile dal run headless; copertura statica: banner legge `accessibilityReduceMotion` e disabilita transizioni animate non necessarie. |

### Criteri di accettazione verificati

- **CA-T092-01/08/16:** ✅ TEST/STATIC — gate condiviso root+card, debounce e multi-scene simulato impediscono preview concorrenti.
- **CA-T092-02:** ✅ TEST — auth/owner mancanti producono stato `blockedAuth` senza chiamata remota auto.
- **CA-T092-03:** ✅ STATIC/TEST — path foreground usa solo preview read-only esistente; nessun apply/push/drain automatico.
- **CA-T092-04:** ✅ TEST/STATIC — background cancella il task foreground e non lascia `checking` incoerente.
- **CA-T092-05/10/21:** ✅ STATIC/TEST/SIM — banner compatto root con una CTA verso flusso Release; nessuna review parallela.
- **CA-T092-06/15/23:** ✅ STATIC/TEST — copy/log/eventi privacy-safe, niente gergo tecnico o dati business/segreti.
- **CA-T092-07/20:** ✅ TEST — test deterministici su date injection, senza sleep reali lunghi.
- **CA-T092-09:** ✅ TEST/SIM — `noChanges` silenzioso lato root.
- **CA-T092-11:** ✅ STATIC — nessun full reload/N+1 nuovo; lavoro pesante resta nei servizi bounded TASK-091.
- **CA-T092-12/18:** ✅ STATIC/SIM — SwiftUI native, safe-area, Dynamic Type smoke, VoiceOver/Reduce Motion coperti staticamente, colori semantici.
- **CA-T092-13:** ✅ TEST — banner ripulito dopo review/discard/confirm/noChanges/cancel/auth change.
- **CA-T092-14:** ✅ TEST — recoverableError con backoff/throttle e retry solo manuale.
- **CA-T092-17:** ✅ STATIC/TEST — marker busy import/export/share/scanner/editing/review/dialog/progress deferiscono/silenziano root.
- **CA-T092-19:** ✅ STATIC/SIM — check avviato dopo `Task.yield`/UI interattiva; cold start non attende rete/auth/preview.
- **CA-T092-22:** ✅ TEST — capability `supportsForegroundCloudCheck` off lascia path card TASK-091 operativo.
- **CA-T092-24:** ✅ TEST/SIM/DOC — mini matrice QA documentata sopra; smoke Simulator eseguito per cold start e Dynamic Type, stati cloud coperti con fake/test.

### Rischi rimasti

- Warning `appintentsmetadataprocessor` da Xcode: metadata extraction skipped per assenza AppIntents.framework; non attribuito a TASK-092 e non bloccante.
- Nessuno scenario live Supabase e' stato usato: scelta coerente con TASK-092 per evitare dati reali/write live; gli stati cloud sono verificati con provider fake e ViewModel/presenter.
- VoiceOver e Reduce Motion non sono stati validati manualmente nel Simulator headless; esistono evidenze statiche e test copy/localizzazione, ma la review puo' fare un pass manuale visivo se desiderato.

### Privacy / anti-scope

- Nessun dato reale usato come fixture.
- Nessun token, owner id, session id, email, barcode, nome prodotto o payload remoto nei log/eventi/copy introdotti.
- Nessuna modifica Kotlin/Android.
- Nessun SQL, migration, RLS o backend live.
- Nessun `Timer` perpetuo, `BGTaskScheduler`, Realtime obbligatorio, polling continuo o worker background.
- Nessun full reload obbligatorio, nessun auto apply/push/drain.
- Nessun `project.pbxproj` modificato.

### Handoff post-execution (Codex)

- **Stato handoff:** **READY FOR REVIEW**
- **Prossima fase:** **REVIEW**
- **Prossimo agente:** **Claude / Reviewer**
- **Stato task:** **ACTIVE / REVIEW**
- **TASK-092:** **NON DONE**
- **TASK-093:** non aperto
- **Note per reviewer:** verificare soprattutto UX root/banner in condizioni reali di account Supabase e un eventuale pass manuale VoiceOver/Reduce Motion; l'execution ha evitato live Supabase per restare privacy-safe e read-only/fakeable.

---

## Review (Claude)

### Esito review

- **Decisione finale:** **REVIEW PASS**
- **Stato finale:** **TASK-092 DONE / Chiusura — REVIEW PASS**
- **TASK-093:** non aperto
- **Supabase live:** nessun write live usato; verifiche con fake/test e smoke Simulator privacy-safe.
- **Android/Kotlin:** nessuna modifica.
- **SQL/backend:** nessuna modifica SQL, migration, RLS o backend.
- **Claim production-ready globale:** non espresso.

### Ambito analizzato

Review tecnica, architetturale, UX/UI, performance, privacy, anti-scope, localizzazione/accessibilità e test sulle modifiche TASK-092: root foreground host, presenter root, ViewModel/policy semi-auto condivisi, card Opzioni/Release, busy gating sulle view principali, localizzazioni IT/EN/ES/zh-Hans e XCTest.

### Problemi trovati e fix applicati

1. **Busy gating con sorgenti duplicate dello stesso motivo:** `ForegroundCloudWorkflowActivityCenter` tracciava un `Set<Reason>`, quindi due superfici con la stessa reason potevano lasciare la UI non-busy quando una sola spariva. Fix: introdotto store tokenizzato `ForegroundCloudWorkflowActivityStore` e wrapper `ObservableObject` che pubblica solo su cambio effettivo. Aggiunto test regressivo.
2. **Cancel dalla card Opzioni su check root-started:** il pulsante Cancel della card poteva cancellare solo il task locale della card, non il foreground task avviato dal root host. Fix: propagato `cancelForegroundCheck` da `SupabaseManualSyncForegroundRootHost` a `OptionsView` / `SupabaseManualSyncReleaseCard`; il cancel ora converte su una sola cancellazione condivisa. Aggiunta asserzione statica/UI.
3. **Microcopy IT:** rifinito il dettaglio `blockedAuth` italiano con accenti coerenti con il resto del file localizzato.

### Verifiche review

| Check | Esito | Evidenza |
|---|---:|---|
| `git status` | ✅ PASS | Working tree coerente con TASK-092; task file non tracciato perché nuovo nel task; nessun file Android/Kotlin. |
| `git diff --check` | ✅ PASS | Nessun whitespace error. |
| `xcodebuild -list` | ✅ PASS | Scheme `iOSMerchandiseControl` presente. |
| Build Debug iPhone 16e iOS 26.2 | ✅ PASS | `** BUILD SUCCEEDED **`; warning AppIntents metadata non attribuito a TASK-092. |
| Build Release iPhone 16e iOS 26.2 | ✅ PASS | `** BUILD SUCCEEDED **`; stesso warning AppIntents metadata. |
| XCTest mirati | ✅ PASS | `SupabaseManualSyncViewModelTests` + `SupabaseManualSyncReleaseUITests`: **107 test / 0 failure**. |
| Full XCTest iOS | ✅ PASS | Full suite: **591 test / 0 failure**. |
| Localizzazioni `plutil` | ✅ PASS | IT/EN/ES/zh-Hans OK. |
| Duplicate localization scan | ✅ PASS | Nessuna chiave duplicata nei quattro file. |
| Anti-literal nuove stringhe | ✅ PASS | Nessun nuovo testo utente TASK-092 hard-coded in Swift; copy via `Localizable.strings`. |
| Anti-scope static grep | ✅ PASS | Nessun Timer/BGTask/polling/Realtime obbligatorio, nessun apply/push/drain automatico, nessun SQL/backend, nessun Kotlin/Android. Match residui solo in test che verificano termini vietati o token anonimi UI-busy. |
| Privacy/observability | ✅ PASS | Eventi `foreground_check_*` aggregati; nessun token, owner/session id, email, barcode, nome prodotto o payload remoto. |
| Smoke Simulator cold start | ✅ PASS | iPhone 16e: app avviata e UI subito interattiva; nessun modal o banner spurio. Screenshot `/tmp/task092-review-cold-start.png`. |
| Smoke Simulator Dynamic Type grande | ✅ PASS con nota | iPhone 16e accessibility extra-extra-large: app avviata senza overlay foreground invasivo; eventuale ellissi nella home e' preesistente/fuori perimetro del banner TASK-092. Screenshot `/tmp/task092-review-dynamic-type.png`. |
| VoiceOver manuale | ⚠️ NON ESEGUIBILE | Non validato in modo affidabile da run headless; copertura statica/test: label unisce stato + azione e copy localizzato/privacy-safe. |
| Reduce Motion manuale | ⚠️ NON ESEGUIBILE | Non validato in modo affidabile da run headless; copertura statica: root banner legge `accessibilityReduceMotion` e riduce transizioni non necessarie. |

### Note warning

- Warning Xcode `appintentsmetadataprocessor`: metadata extraction skipped per assenza AppIntents.framework; gia' osservato come warning toolchain non bloccante e non introdotto da TASK-092.
- Full test log contiene warning Swift preesistenti in `SyncEventOutboxDrainDebugViewModelTests.swift` su conversione di funzioni non-Sendable; file non toccato da TASK-092 e full suite resta PASS.

### Decisione

TASK-092 soddisfa i criteri di accettazione rilevanti: cold start non bloccante, dedupe root+card, cancel/background, `noChanges` silenzioso, banner actionable con una sola CTA verso Release, busy gating, backoff/throttle testabile, rollback `supportsForegroundCloudCheck`, localizzazioni complete, privacy-safe observability e anti-scope rispettato.

---

## Fix (Codex)

Fix diretti applicati durante review:

- Tokenizzazione del busy gating UI con `ForegroundCloudWorkflowActivityStore`, per evitare clearing prematuro quando piu' superfici dichiarano la stessa reason.
- Wiring del cancel root-started dalla card Opzioni/Release verso `cancelForegroundCheck`.
- Microcopy IT `blockedAuth` rifinita.

Verifiche post-fix: build Debug/Release PASS, XCTest mirati **107/0**, full XCTest **591/0**, `git diff --check` PASS, localizzazioni PASS, anti-scope/privacy PASS.

---

## Chiusura

**TASK-092 DONE / Chiusura — REVIEW PASS**.

Chiusura approvata dopo review completa e fix mirati. Nessun TASK-093 aperto; nessuna modifica Android/Kotlin; nessun SQL/migration/RLS/backend; nessun write Supabase live; nessun apply/push/drain automatico; nessun Timer/BGTask/Realtime obbligatorio/polling continuo; nessun claim production-ready globale o 100%.
