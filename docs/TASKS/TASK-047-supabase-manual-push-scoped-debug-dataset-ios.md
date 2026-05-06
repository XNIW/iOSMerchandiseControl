# TASK-047: Supabase manual push scoped debug dataset iOS — filtro `TASK045_*`, dry-run scoped DEBUG *(live/read-back solo TASK-045)*

## Informazioni generali
- **Task ID**: TASK-047
- **Titolo**: Supabase manual push scoped debug dataset iOS: filtro `TASK045_*`, dry-run scoped DEBUG *(nessun push/read-back live in TASK-047; live = TASK-045)*
- **File task**: `docs/TASKS/TASK-047-supabase-manual-push-scoped-debug-dataset-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Claude / Reviewer
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(review tecnica severa completata con esito APPROVED_FIXED_DIRECTLY / DONE; fix diretto scope guardrail; build/test/check PASS; nessun push live, nessuna scrittura remota, nessuna modifica Supabase config/schema/Android).*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer
- **Nota**: **TASK-047 chiuso DONE / Chiusura** su override utente per review severa; **TASK-045 resta BLOCKED** e non DONE, riprendibile solo con nuovo override utente esplicito da collision check + dry-run scoped.

## Dipendenze
- **Dipende da**:
  - **TASK-044** — DONE — push manuale reale baseline-gated (`SupabaseManualPushPreflightService`, `SupabaseManualPushService`, UI DEBUG in `OptionsView`).
  - **TASK-042 / TASK-041** — DONE — modelli piano/preview preflight dry-run.
  - **TASK-043** — DONE — baseline reader/writer; lo scope non sostituisce baseline valida né account gate.
  - **TASK-046** — DONE / Chiusura — baseline locale valida; prerequisito **T45-02** soddisfatto lato baseline.
  - **TASK-038** — DONE — auth/session.
- **Sblocca proceduralmente**: strumentazione e prerequisiti per una ripresa **TASK-045** sicura dopo review positiva TASK-047 + codice dei guardrail *(vedi confine sotto)*.

### Confine TASK-047 vs TASK-045 *(obbligatorio)*
- **TASK-047** progetta — e in EXECUTION deve implementare e coprire con test — esclusivamente: **filtro scoped**, dry-run scoped, UX DEBUG opt-in **e guardrail sul payload**, così la modalità scoped non possa essere usata senza controlli coerenti.
- **TASK-047 non esegue push live** né read-back né cicli di validazione TASK-045; nell’EXECUTION TASK-047 è **vietato** pubblicare modifiche sul tenant Supabase live (nemmeno come prova corta).
- **Il primo push live controllato** resta nell’EXECUTION autorizzata di **TASK-045**, **dopo** review positiva di TASK-047 sull’intervento scoped e **dopo nuovo user override** esplicito verso EXECUTION TASK-045.
- **TASK-045** alla ripresa: prima **collision check**, poi **dry-run/preflight scoped** progettati in TASK-047 — **non** ripartendo dal **push** se i gate non sono verdi; **non saltare il dry-run** per arrivare subito alla write.

*(La UI dello scope potrà essere riusata in TASK-045: la **`confirmationDialog` push scoped live**, read-back TASK-045 e CA live sono perimetro TASK-045, non TASK-047.)*

## Contesto TASK-045 *(stato atteso MASTER-PLAN: BLOCKED invariato)*
- **TASK-045** è **BLOCKED** al **dry-run scope gate** *(post TASK-046)*: dataset locale `TASK045_*` creato, collision check OK, ma il preflight globale conta anche **local-only** non `TASK045_*`:
  - **2** supplier create, **3** category create, **1** product create *(oltre al triplet di test autorizzato)*.
- Policy **TASK-045**: STOP prima di push live; **nessuna** scrittura remota eseguita.
- **TASK-047** non completa TASK-045; definisce come isolare solo il dataset di test nei passi dry-run / futuro payload.

## Obiettivo *(planning-only in questo task)*
Pianificare un micro-intervento sicuro che consenta:
1. aggiunta o uso di uno **scope/filter** nel flusso **DEBUG** «manual push / preflight»;
2. **dry-run/preflight** che riportano conteggi e piano pertinenti solo a record **`TASK045_*`** in modalità scoped;
3. **predisporre il blocco di ogni push** *(eseguibile solo in TASK-045 con override)* se, in modalità scoped, esisterebbero record **fuori** scope nel percorso di write *(fail-closed; nessun bypass silenzioso)*;
4. **nessuna** cancellazione né «pulizia» automatica dei candidati local-only preesistenti;
5. **nessuna** alterazione distruttiva di dati SwiftData non correlati come scorciatoia;
6. dopo TASK-047, **TASK-045** possa ripartire da **collision check + dry-run scoped**; il **primo push live** rimane solo in TASK-045, **unicamente** dopo override TASK-045 e gate verdi (mai come deliverable TASK-047).

## Fuori scope tassativo
- Nessun push live / scrittura remota / delete remota **in questo turno TASK-047** *(transition EXECUTION-start / solo tracking)*.
- Nessun ProductPrice push, `record_sync_event`, `sync_events`, outbox, sync automatico/background/realtime.
- Nessun SQL/RPC/RLS/migration, nessun `service_role`.
- Nessuna modifica Android; nessun wipe/reset locale; nessun dataset grande.
- Nessun completion **TASK-045** né dichiarazione **TASK-045 DONE** dentro TASK-047.
- In questo turno transition-only: nessuno Swift; nessun build / XCTest / evidenza runtime *(Execution tecnica = turno successivo su istruzione utente).*

*(Allinea **S47-08** e **CA47-10**.)*

## Fonti lette *(repo iOS — lettura solo; nessuna modifica sorgente nei turni tracking / transition-only)*
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- `docs/TASKS/TASK-046-supabase-baseline-recovery-full-pull-ios.md`
- `docs/TASKS/TASK-044-supabase-manual-push-reale-controllato-ios.md` *(porzione architetturale superiore)*
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift` — `ManualPushPreflightInput`; `makePlan` classifica **tutti** supplier/category/product dall’input senza prefisso test.
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift` — orchestrazione stati blocked/safe, summary.
- Individuate via codebase: `SupabaseManualPushService.swift`, `OptionsView.swift`, `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineWriter.swift` *(citazione layering; lettura mirata in EXECUTION).*

---

## Matrice progettuale S47

| ID | Titolo | Contenuto atteso |
|----|--------|------------------|
| **S47-01** | Audit candidati local-only | In EXECUTION: perché il dry-run globale conta 2 supplier / 3 category / 1 product create *(residui import, dup lookup, test manuali, post-pull locale, ecc.)* — **solo osservazione documentata**, nessuna delete. |
| **S47-02** | Scope design | Prefisso `TASK045_` **vs** whitelist ID esatti run; opt-in DEBUG-only (**Decisioni**). |
| **S47-03** | Preflight scoped no-write | Dry-run scoped: candidati **`create/link/update`** conteggiati solo per record in scope; **zero** POST/PATCH remoto nel preflight. |
| **S47-04** | Out-of-scope blocker | Piano che **in un futuro path di write** *(TASK-045, non TASK-047)* implicherebbe push di candidati fuori scope ⇒ **blocked** dedicato + contatori/sommario sicuro in UI. |
| **S47-05** | Payload scoped (guardrail) | Layer servizio/builder: solo subset supplier/category/product ammessi dallo scope; ordine TASK-044 incapsulato; **write remota effettiva solo in TASK-045** autorizzata. |
| **S47-06** | UI DEBUG clarity | Globale vs **Scoped** (prefisso TASK045_), badge *Scoped / Blocked fuori scope / Safe*, una CTA primaria per modalità. |
| **S47-07** | Idempotenza scoped | Ripetere scoped dry-run: stabilità salvo modifiche intentional al dataset test. |
| **S47-08** | Anti-scope | Nessun ProductPrice/sync_event/outbox/tombstone/SQL/Android/wipe. |
| **S47-09** | TASK-045 handoff | Post TASK-047 approvato: TASK-045 **resta BLOCKED** finché nuovo override; ripresa da collision + scoped dry-run, non salto diretto push. |

---

## Criteri di accettazione *(CA47 — futura EXECUTION/REVIEW)*

- [ ] **CA47-01** — Build **Debug** PASS (dopo modifiche codice future).
- [ ] **CA47-02** — Build **Release** PASS *(schema progetto corrente)*; **nessuna** superficie UI scoped *(toggle/badge/CTA dry-run o push scoped)* verso utente finale — allineamento **D2** / § *Approccio tecnico* *(eventuale core compilato senza esposizione UI).*
- [ ] **CA47-03** — XCTest mirato **e/o** suite completa PASS se codice toccato.
- [ ] **CA47-04** — `git diff --check` PASS.
- [ ] **CA47-05** — Nessun segreto/token tracciato.
- [ ] **CA47-06** — Nessuna scrittura remota sul tenant nel perimetro TASK-047 *(planning ora; in EXECUTION TASK-047 vietato anche smoke push live prima della dichiarazione chiusura del task).*
- [ ] **CA47-07** — Dry-run **scoped**: conteggi operativi includono **solo** candidati in scope secondo § *Regole membership* *(stesse normalizzazioni già usate nel preflight; niente logica parallela).*
- [ ] **CA47-08** — In modalità scoped, presenza di candidati fuori scope nel **percorso di write che abiliterebbe push** *(scenario TASK-045; TASK-047 resta no-network per push)* ⇒ **push bloccato** + UX esplicita.
- [ ] **CA47-09** — Payload push **futuro TASK-045**: solo suppliers/categories/products **scoped** (*nessun* create/update lookup fuori prefisso).
- [ ] **CA47-10** — Nessuna introduzione nel perimetro TASK-047 di ProductPrice/sync_event/outbox/tombstone/delete outbound.
- [ ] **CA47-11** — Se si aggiungono nuove stringhe UI in EXECUTION: copertura **IT / EN / ES / ZH-Hans** (allineamento standard **OptionsView**), copy breve e coerente.
- [ ] **CA47-12** — **TASK-045 BLOCKED** finché TASK-047 non è reviewato positivamente **e** l’utente non concede override ripresa TASK-045.
- [ ] **CA47-13** — Nessun wipe/reset locale nella soluzione.

---

## Decisioni *(proposta PLANNING — da confermare in review / execution kickoff)*

| # | Domanda planner | Decisione **proposta** | Motivazione sintetica |
|---|----------------|------------------------|------------------------|
| **D1** | Prefisso `TASK045_` vs ID esatti? | Prefisso su chiavi dopo le **stesse** normalizzazioni del preflight supplier/category/product *(vedi § Regole membership)* | Allineamento TASK-045; whitelist ID solo fallback se ambiguità in S47-01 |
| **D2** | Solo DEBUG vs generico? | **Superficie UI scoped solo DEBUG** (`OptionsView` / card DEBUG): l’utente finale in **Release** non vede toggle/badge/CTA per dry-run o push scoped. Il **codice core** di scope/preflight/guardrail **può** restare compilato anche in **Release** *(test/architettura / CA47-02)* purché **non** esponga controlli utente produttivi per lo strumento scoped. Se si usa `#if DEBUG`, **documentare nel diff i punti esatti** — preferibilmente **UI** (`OptionsView` o wrapper SwiftUI collegato), **non necessariamente** model/service. **Release build PASS** e zero strumenti scoped esposti all’utente finale. | Elimina ambiguità «feature assente in Release» vs «feature compilata ma non esposta in UI»; riduce footgun push parziale accidentale in prod |
| **D3** | Dove filtrare? | § *Guardrail a due livelli* — VM/UI + service, **entrambi obbligatori** | Defence in depth |
| **D4** | Blocco fuori-scope | Stati **blocked** se create/update/link reali fuori prefisso o dipendenze lookup non conformi § membership | Nessuno stato «Safe» fuorviante |
| **D5** | Conteggi in UI | Riga «Inclusi scope / Fuori scope (esclusi)» + badge; niente dump sensibile | QA operativo |
| **D6** | Footgun | Default **Globale**; scoped opt-in esplicito; `confirmationDialog` push riservato a ripresa TASK-045 *(CA live)* | Copy breve **IT / EN / ES / ZH-Hans** come standard **OptionsView** |
| **D7** | Lookup dipendenti | Lookup senza prefisso: vietato nel **payload scoped** qualunque create/update; se hanno solo `remoteID` valido senza bisogno di write nuova → **solo dipendenza remota**, da riportare nei conteggi come *dipendenza non scritta* se utile | Coerenza con TASK-045 tripletto senza creep |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

*(Il planning sotto è **accettato come base dell’EXECUTION**; non riscrivere — modifiche solo su decisione/review esplicita.)*

### Regole membership — cosa significa «in scope» *(scelta PLANNING TASK-047)*
Applicare **solo in modalità scoped**; sempre con le **medesime** funzioni di normalizzazione già usate da `SupabaseManualPushPreflightService` *(es. `SupabasePullPreviewNormalizer.normalizedLookupName` per nomi supplier/category; `ManualPushFingerprintNormalizer.semanticString`, o equivalenti effettivamente invocati dal preflight sul barcode, per prodotti).* **Non** introdurre una seconda catena di normalizzazione divergente *(evita falsi positivi/negativi).*

| Entità | Criterio **in scope** |
|--------|----------------------|
| **Supplier** | Nome *(dopo normalizzazione lookup supplier)* **che inizia con** letterale `TASK045_` sul risultato normalizzato. |
| **ProductCategory** | Come supplier: nome categorico dopo **stessa** normalizzazione category usata nel preflight, prefisso `TASK045_`. |
| **Product** | **Primario**: barcode dopo **stessa** normalizzazione barcode usata nel preflight **inizia con** `TASK045_`. **Fallback** *(solo se strettamente necessario, es. assenza barcode in edge case QA)*: `productName` dopo normalizzazione coerente con i campi testo già usati nei fingerprint prodotti deve iniziare con `TASK045_`. Preferenza operativa progettuale: **identificatore di test = barcode** per ridurre collisioni su nomi. |

**Dipendenze lookup** *(supplier/category collegati a un Product in-scope)*:
- Product in-scope che punta a supplier/category **fuori prefisso** **e senza** `remoteID`: piano scoped ⇒ **blocked** *(stato tipo «fuori scope / dipendenze»)* — nessuna write, nessun dry-run «verde» che suggerisca push.
- Supplier/category **fuori prefisso** ma con **`remoteID` valido** e **nessun** create/update richiesto per loro nel piano: ammessi **solo** come riferimento remoto esistente; **documentare** nei conteggi UI/summary come *dipendenza remota, non oggetto di write locale in questo scope* *(nessun create/update fuori prefisso nel payload scoped).*
- **Regola payload**: in modalità scoped, **nessun** `create` / `update` / `link` che materializzi o modifichi record **fuori** prefisso può entrare nel payload eseguibile.

### Guardrail a due livelli *(obbligatori; EXECUTION futura)*
1. **Livello 1 — `SupabasePushPreflightViewModel` + UI DEBUG (`OptionsView`)**  
   - Costruisce **input** preflight coerente con la modalità *(Globale invariata vs Scoped opt-in)*.  
   - Mostra conteggi **inclusi** vs **esclusi** *(fuori scope)* e stati blocked dedicati.  
   - **Disabilita** la conferma verso push se `fuori-scope > 0` in modalità scoped o se il riepilogo indica dipendenze non ammissibili *(vedi membership).*  
   - *Nota TASK-047:* durante EXECUTION TASK-047 la UI **non** espone alcuna CTA «push live»; solo dry-run scoped e preparazione stati/copy per TASK-045.
2. **Livello 2 — `SupabaseManualPushPreflightService` e/o `SupabaseManualPushService`**  
   - Rivalutazione **deterministica** dello scope sugli snapshot/candidati **prima di qualsiasi** POST/PATCH/DELETE remoto quando la sessione è in modalità scoped.  
   - Se **qualsiasi** operazione pianificabile non è in-scope: **fail locale** *(nessuna rete)*, stato errore/blocco esplicito.  
   - Il controllo service è **obbligatorio** anche se livello 1/UI sembra corretta *(tampering, race sul ModelContext, bug UI).*

**Fuori-scope: stato tipizzato *(EXECUTION futura — solo planning ora)***  
Il blocco per candidati fuori scope / dipendenze non conformi **non** deve essere solo testo UI. In EXECUTION preferire uno **stato macchina tipizzato** assertabile da XCTest **senza** dipendere da stringhe localizzate — es. `blockedOutsideScope`, `blockedScopedDependency`, oppure **case enum / outcome** già presenti in `SupabasePushPreflightViewModel` / pipeline preflight *(**riusare** ed estendere se equivalenti; evitare enum duplicati semantici).* Regole: la UI **localizza solo** il messaggio finale mappato dallo stato; i conteggi **`included` / `excludedOutsideScope` / `blockedDependencies`** *(o nomi coerenti col summary esistente)* restano in un **model/summary testabile** inspectabile dai test.

Riprendere comunque **`frozenConfirmationPlan` / fingerprint** TASK-044 per incoerenze tra preflight e momento write.

### Analisi
Il path attuale in `SupabaseManualPushPreflightService.makePlan` enumera tutti gli elementi dell’input SwiftData. Gli indicatori delle **sei** crea distribuite fuori prefisso test sono coerenti con un catalogo locale ricco dopo pull/import: non richiedono delete né wipe. Prima del primo push TASK-045 serve una **modalità scoped** DEBUG che applichi le regole sopra senza mutare i record esclusi.

### Approccio tecnico proposto *(EXECUTION futura — cambiamento minimo)*
**Debug vs Release (allinea D2):** la modalità **scoped** è una **superficie UI DEBUG-only**; l’utente **Release** non deve vedere CTA/controlli per dry-run scoped né strumenti di push scoped. Il layer **core** *(scope su input, classificazione membership, guardrail L2)* può restare **nel binary Release** se utile a coerenza architetturale e a **CA47-02**, ma **senza** ingressi UI produttivi; eventuali `#if DEBUG` vanno **documentati file-per-file** *(priorità: `OptionsView` / wrapper UI DEBUG, non necessariamente ViewModel/servizio).*  

1. Introdurre parametro scope su `ManualPushPreflightInput` *(o tipo affiancato)*: `.global` vs `.scopedTask045(..)` testabile XCTest senza SwiftUI quando possibile.
2. In `makePlan` *(o stratificazione immediatamente dopo)*: quando scoped, applicare § membership **prima/e durante** `classify*` così solo candidati in-scope entrano nei conteggi operativi; accumulare `excludedOutsideScopeCount` *(e metadati non sensibili).*
3. `SupabaseManualPushService`: subito prima della prima write remota **in un flusso autorizzato *(TASK-045)*** ripetere § membership sul piano congelato; mismatch ⇒ `precondition`/return failure **senza rete** *(TASK-047 non esegue tale write in chiusura task)*.
4. Test: vedi § *Test plan futuro*.

### Test plan futuro *(EXECUTION — elenco minimale)*

Implementare XCTest/fixture in-memory *(nessun codice in questo task).*

| Caso | Atteso sintetico |
|------|------------------|
| Helper scope | Supplier/category/product con nomi/barcode `TASK045_*` dopo normalizzazione ⇒ **in scope** |
| Falsi positivi | Stringhe «simili» ma senza prefisso valido post-normalizzazione ⇒ **non** in scope |
| Preflight scoped misto | Dataset 1 supplier + 1 category + 1 product `TASK045_*` più rumore locale ⇒ conteggio scoped = solo 1/1/1 *(create/idempotenza coerenti col piano).* |
| Rumore prefisso | Local-only fuori prefisso ⇒ `esclusi > 0`; push confermabile **mai** parte in scoped |
| Product + lookup fuori prefisso senza remoteID | Stato blocked (dipendenze) |
| Product + lookup fuori prefisso con remoteID stabile senza loro create/update | Nessuna write lookup; solo product (e lookup TASK045 se presenti nel piano) nei payload scoped |
| Modalità Globale | Comportamento invariato rispetto a baseline TASK-042/044 |
| Payload builder | Nessun supplier/category/product fuori prefisso nelle richieste di write scoped |
| Anti-scope grep | Nessun ProductPrice/`record_sync_event`/`sync_events`/outbox/delete/tombstone outbound introdotto dal diff |
| Stati tipizzati | Blocco fuori-scope / dipendenze: assert su **enum o summary model**, non su testo localizzato *(vedi § Guardrail)* |

### UX proposta *(solo planning — nessuna implementazione ora)*
- **Default**: modalità **Globale** *(o equivalente al comportamento attuale visibile oggi in DEBUG)* — **nessun cambio di default** rispetto all’esperienza corrente finché l’utente non opta per lo scope.
- **Scoped**: **opt-in esplicito**, controlli visibili **solo in build DEBUG** / sezione DEBUG esistente.
- **CTA primaria in modalità scoped** *(TASK-047 / strumentazione dry-run)*: etichetta tipo **«Esegui dry-run scoped»** *(o stringa localizzata equivalente).*
- **Push live**: **non** parte del deliverable TASK-047; nessuna CTA push live abilitata per «validare» TASK-047.
- **TASK-045 futura**: eventuale CTA **push scoped** con `confirmationDialog` che riporta conteggi **inclusi** e **esclusi**; se `fuori-scope > 0` ⇒ stato **Blocked fuori scope** e push disabilitato.
- Copy **breve**, **localizzato** **IT / EN / ES / ZH-Hans** *(standard **OptionsView**)*; niente wizard multi-step.

### Rischi rimasti nel planning
- Normalizzazione nomi/barcode: mitigare con test su helper condivisi *(§ Test plan futuro).*
- Prefisso editabile troppo corto: default `TASK045_`, edit solo avanzato.
- Interazione tombstone/baseline/account: EXECUTION definisce priorità messaggi se più badge attivi.

### Handoff → Execution *(storico pre-transition — CA operative nella § Execution Codex)*
- **Prossima fase**: EXECUTION *(raggiunta 2026-05-06 su user override execution-start)*
- **Prossimo agente**: CODEX
- **Post-transition (2026-05-06):** TASK-047 è **ACTIVE / EXECUTION**; questo turno = solo tracking + § Execution — **implementazione Swift** solo dopo **istruzione utente esplicita** *(vedi Handoff post-transition in § Execution)*.
- **Azione consigliata (Execution tecnica futura)**: (1) S47-01 audit; (2) membership + guardrail L1/L2; (3) XCTest § *Test plan futuro*; (4) REVIEW **senza** push live **né in TASK-047 né come sostituto TASK-045**.

### Handoff → TASK-045 *(meta)*
Dopo TASK-047 chiuso/reviewato: aggiornare tracking «strumenti scoped pronti»; **TASK-045 resta BLOCKED** finché l’utente non autorizza EXECUTION TASK-045. Ripresa: **collision check → dry-run scoped →** *(gate TASK-045)* **→** push live solo in TASK-045.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Implementare il filtro scoped DEBUG `TASK045_*` per il manual push iOS in modo che il dry-run/preflight possa isolare il dataset test autorizzato e bloccare localmente qualsiasi record fuori scope prima di un futuro push live in **TASK-045**.

Confine rispettato: **TASK-047 non esegue push live**, non fa scritture remote e non completa TASK-045.

### File controllati
- `docs/TASKS/TASK-047-supabase-manual-push-scoped-debug-dataset-ios.md`
- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift` *(lettura, nessuna modifica)*
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift` *(lettura, nessuna modifica)*
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift` *(lettura, nessuna modifica)*
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushServiceTests.swift`
- `iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests.swift`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`

### Piano minimo
1. Safety gate e lettura fonti di verità.
2. Lettura call path reali preflight/service/ViewModel/UI/baseline.
3. Audit S47-01 solo osservazionale dei candidati local-only TASK-045.
4. Aggiunta scope `.global` invariato e `.scopedTask045` testabile.
5. Filtro scoped nel preflight con summary `included/excludedOutsideScope/blockedDependencies`.
6. Guardrail L1 ViewModel/UI DEBUG e L2 service fail-closed prima di qualsiasi rete futura.
7. Stati tipizzati e localizzazioni.
8. XCTest mirati, build Debug/Release, suite completa, check anti-scope/segreti.
9. Tracking e handoff a Review.

### Modifiche fatte
- Aggiunto `ManualPushPreflightScope` con modalità `.global` e `.scopedTask045`; `.global` resta default e preserva il comportamento precedente.
- Aggiunto helper testabile `ManualPushTask045Scope` che riusa le normalizzazioni esistenti: supplier/category via `SupabasePullPreviewNormalizer.normalizedLookupName`; product via `ManualPushFingerprintNormalizer.semanticString` sul barcode, con fallback `productName` solo se il barcode normalizzato manca.
- Aggiunti stati tipizzati `blockedOutsideScope` e `blockedScopedDependency`, reason `PushBlockedReason` dedicate e `ManualPushScopeSummary` con `included`, `excludedOutsideScope`, `blockedDependencies`.
- Esteso `SupabaseManualPushPreflightService` per filtrare supplier/category/product in modalità scoped, escludere rumore fuori prefisso, bloccare dipendenze lookup local-only fuori prefisso e non aggiungere `ProductPrice` future-only nel piano scoped.
- Esteso `SupabaseManualPushService` con guardrail L2: in piano scoped ricontrolla i candidati prima della prima write remota futura e fallisce localmente se trova payload fuori scope, `ProductPrice`, o lookup fuori prefisso senza `remoteID`.
- Esteso `SupabasePushPreflightViewModel` con input scoped, summary scoped, stati `completedScopedSafe` / `completedScopedBlocked` e blocco conferma futura in presenza di scoped blocker.
- Aggiornata UI DEBUG in `OptionsView`: selettore opt-in Globale/TASK045, una sola CTA primaria per dry-run scoped, conteggi scope e nessuna CTA push live visibile nel perimetro TASK-047.
- Aggiornate localizzazioni IT / EN / ES / ZH-Hans.
- Aggiunti XCTest in-memory/no-network per scope helper, preflight scoped/globale, dipendenze lookup, guardrail service, stati ViewModel e copertura localizzazioni.

### Audit S47-01
- Evidenza TASK-045: dry-run globale no-write con `2` supplier create, `3` category create, `1` product create contro dataset test autorizzato atteso `1/1/1`.
- Comportamento osservato nel codice: il preflight globale enumera tutti i record SwiftData local-only nello snapshot, quindi candidati supplier/category non `TASK045_*` vengono legittimamente conteggiati senza filtro.
- Causa probabile documentata: rumore locale residuale/import/manuale dopo pull/apply e test precedenti; il product create appare coerente con il product TASK045 autorizzato, mentre l'extra noise è nei lookup.
- Nessun record locale è stato cancellato, modificato o pulito.
- Probe runtime dello store via `simctl get_app_container` non completato perché il simulatore era shutdown; non ho bootato né alterato lo stato locale per non introdurre azioni non richieste.

### S47-01...S47-09
| ID | Esito | Evidenza |
|----|-------|----------|
| S47-01 | PASS | Audit documentale/statico TASK-045 completato; nessuna delete/wipe. |
| S47-02 | PASS | Scope `TASK045_` implementato con helper testabile e normalizzazioni esistenti. |
| S47-03 | PASS | Preflight scoped no-write filtra record operativi e produce summary scoped. |
| S47-04 | PASS | `blockedOutsideScope` / `blockedScopedDependency` tipizzati bloccano piano scoped. |
| S47-05 | PASS | Guardrail service ricontrolla il payload scoped e fallisce localmente prima della rete. |
| S47-06 | PASS | UI DEBUG con opt-in scope, badge/stati e una sola CTA dry-run scoped; nessuna CTA push live. |
| S47-07 | PASS | XCTest coprono idempotenza/determinismo in-memory del piano scoped. |
| S47-08 | PASS | Diff scan anti-scope: nessun push ProductPrice/event/outbox/delete/tombstone outbound/SQL/Android. |
| S47-09 | PASS | Handoff mantiene TASK-045 BLOCKED; ripresa futura solo da review positiva + override TASK-045. |

### CA47-01...CA47-13
| ID | Esito | Evidenza |
|----|-------|----------|
| CA47-01 | PASS | Build Debug PASS su iPhone 16e iOS 26.2. |
| CA47-02 | PASS | Build Release PASS; superficie scoped solo nella sezione `#if DEBUG` di `OptionsView`. |
| CA47-03 | PASS | XCTest mirati PASS; XCTest completo PASS. |
| CA47-04 | PASS | `git diff --check` PASS. |
| CA47-05 | PASS | Diff secret scan PASS; nessun token/URL reale/JWT/email completa introdotti. |
| CA47-06 | PASS | Nessuna scrittura remota e nessun push live eseguiti; test con fake gateway/no-network. |
| CA47-07 | PASS | Dry-run scoped include solo candidati `TASK045_*`; rumore fuori prefisso escluso e contato. |
| CA47-08 | PASS | Scoped blockers impediscono conferma futura in ViewModel e fail-closed nel service. |
| CA47-09 | PASS | Service guardrail impedisce payload scoped con supplier/category/product fuori prefisso. |
| CA47-10 | PASS | Nessun ProductPrice/sync_event/outbox/tombstone/delete outbound introdotto; `ProductPrice` solo bloccato/testato come esclusione scoped. |
| CA47-11 | PASS | Nuove stringhe coperte in IT / EN / ES / ZH-Hans e da `LocalizationCoverageTests`. |
| CA47-12 | PASS | TASK-045 resta BLOCKED nel tracking; nessun avanzamento a DONE. |
| CA47-13 | PASS | Nessun wipe/reset locale. |

### Check eseguiti
- ✅ ESEGUITO — `git status --short` iniziale: solo tracking docs attesi (`docs/MASTER-PLAN.md` modificato, `TASK-047` non tracciato); nessuna modifica inattesa Swift/Supabase/Android al safety gate.
- ✅ ESEGUITO — Verifica tracking iniziale: TASK-047 `ACTIVE / EXECUTION`; TASK-045 `BLOCKED`; TASK-046 `DONE / Chiusura`.
- ✅ ESEGUITO — `SupabaseConfig.plist` reale non toccato e non stampato.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` PASS; scheme `iOSMerchandiseControl`.
- ✅ ESEGUITO — XCTest mirati PASS: `SupabaseManualPushPreflightTests`, `SupabaseManualPushServiceTests`, `SupabasePushPreflightViewModelTests`, `LocalizationCoverageTests`.
- ✅ ESEGUITO — Build Debug PASS: `xcodebuild build -configuration Debug -destination id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B`.
- ✅ ESEGUITO — Build Release PASS: `xcodebuild build -configuration Release -destination id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B`.
- ✅ ESEGUITO — XCTest completo PASS: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B`.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — Scan anti-scope sul diff PASS; uniche nuove occorrenze `ProductPrice` sono il guardrail che lo blocca in scoped e il test che verifica l'esclusione.
- ✅ ESEGUITO — Scan segreti sul diff PASS: nessun match introdotto.
- ✅ ESEGUITO — Nessun warning Swift nuovo riconducibile al diff; le build mostrano solo warning metadata AppIntents di toolchain/esistente.
- ⚠️ NON ESEGUIBILE — Audit runtime diretto dello store simulator non completato perché il simulator target era shutdown; per non alterare stato locale non ho bootato né eseguito wipe/reset. Audit S47-01 completato su evidenze TASK-045 e call path.

### Debug vs Release
- `#if DEBUG` usato sulla superficie UI già esistente in `OptionsView`: selettore scoped, copy, conteggi e CTA dry-run scoped sono visibili solo in DEBUG.
- Model, preflight, ViewModel e service guardrail compilano anche in Release come core sicuro/testabile.
- Release build PASS e nessuna CTA/controllo scoped esposto all'utente finale.

### Anti-scope e sicurezza
- Nessun push live.
- Nessuna scrittura remota.
- Nessun POST/PATCH/DELETE eseguito.
- Nessun read-back remoto TASK-045.
- Nessun ProductPrice push.
- Nessun `record_sync_event`, `sync_events`, outbox, sync automatico/background/realtime.
- Nessuna delete remota o tombstone outbound.
- Nessun SQL/RPC/RLS/migration.
- Nessun `service_role`.
- Nessuna modifica Android.
- Nessun wipe/reset/cancellazione locale.
- Nessuna modifica a `SupabaseConfig.plist` reale.

### Rischi rimasti
- Il primo uso runtime sul dataset locale reale `TASK045_*` non è stato eseguito in TASK-047 per non trasformare questo task in ripresa TASK-045; va fatto in TASK-045 dopo review positiva e override utente.
- La UI conserva codice privato di conferma push già esistente, ma TASK-047 ha rimosso la CTA visibile nella card DEBUG; review può decidere se richiedere ulteriore dead-code cleanup come task separato.
- Il rumore locale fuori prefisso resta intenzionalmente nel database locale; lo scope lo esclude/blocca, non lo pulisce.

### Handoff post-execution
TASK-047 passa a **`ACTIVE / REVIEW`**.

**Prossimo agente:** Claude / Reviewer.

**Sintesi handoff:** filtro scoped `TASK045_*`, dry-run DEBUG scoped, summary conteggi, stati tipizzati, guardrail ViewModel/UI e service fail-closed sono implementati e coperti da test. Build Debug/Release, XCTest mirati/completo, `git diff --check`, localizzazioni, anti-scope e secret scan risultano PASS. Nessun push live o write remota eseguiti. **TASK-045 resta BLOCKED**.

---

## Review (Claude)

### Esito
**APPROVED_FIXED_DIRECTLY / DONE**.

La review tecnica severa ha trovato un problema medio nel guardrail scoped: il summary trattava ogni record escluso fuori prefisso come blocker anche quando il record non entrava nel payload e una dipendenza lookup remota era valida. Questo confliggeva con la regola TASK-047 che consente supplier/category fuori prefisso solo come dipendenza remota esistente con `remoteID` valido e senza create/update/link. Fix applicato direttamente e verificato.

### Fix diretti applicati
- `ManualPushScopeSummary.hasScopedBlocker` ora blocca solo su `blockedDependencies > 0`; gli `excludedOutsideScope` restano conteggiati e visibili ma non impediscono un piano scoped altrimenti valido.
- `categoryCounts` non promuove piu' gli esclusi fuori scope a `blockedOutsideScope`; lo stato bloccante resta tipizzato come `blockedScopedDependency` quando c'e' una dipendenza lookup non ammissibile.
- La membership lookup supplier/category usa il nome normalizzato, non `localID`, evitando falsi positivi con ID locali `TASK045_*`.
- Aggiunti/aggiornati test per dipendenza remota fuori prefisso ammessa, lookup fuori prefisso con `localID` TASK045 ma nome fuori prefisso bloccato, stato ViewModel scoped safe con rumore escluso e guardrail service no-network.
- Microcopy localizzata del blocco scoped resa generica su IT / EN / ES / ZH-Hans.

### Verifica punti critici
- Confine TASK-047/TASK-045: PASS. TASK-047 non esegue push live, non fa read-back live, non completa TASK-045 e non espone CTA push live.
- Modalita' globale: PASS. `.global` resta default e il comportamento TASK-044 resta invariato dai test global mode.
- Membership scoped: PASS dopo fix. Supplier/category via nome normalizzato; product primario via barcode normalizzato, fallback `productName` solo se barcode normalizzato vuoto; falsi positivi coperti.
- Dipendenze lookup: PASS dopo fix. Product in scope + lookup fuori prefisso senza `remoteID` valido blocca; lookup fuori prefisso con `remoteID` valido resta solo riferimento remoto non scritto.
- Guardrail L1/L2: PASS. ViewModel/UI espongono stati typed e disabilitano conferma futura su blocker; service ricontrolla fail-closed prima della prima write futura e fallisce localmente senza rete.
- Stati tipizzati: PASS. `blockedOutsideScope` / `blockedScopedDependency` e summary `included/excludedOutsideScope/blockedDependencies` sono assertabili senza stringhe localizzate.
- Debug vs Release: PASS. Superficie scoped visibile solo in `OptionsView` DEBUG; core model/service compila in Release senza controlli utente.
- UI/UX: PASS. SwiftUI nativa, coerente con `OptionsView`, una CTA primaria dry-run scoped, conteggi leggibili, nessun wizard e nessuna CTA push live.
- Test: PASS. Copertura mirata presente per helper, falsi positivi, preflight scoped misto, rumore local-only, lookup con/senza `remoteID`, global mode, service guardrail, stati ViewModel e localizzazioni.
- Anti-scope: PASS. Nessun ProductPrice push, `record_sync_event`, `sync_events`, outbox, delete remota, tombstone outbound, SQL/RPC/RLS/migration, `service_role`, Android, wipe/reset o completamento TASK-045.

### Check eseguiti in review
- ✅ ESEGUITO — `git status --short`: file modificati coerenti col perimetro dichiarato; `TASK-047` risulta untracked perche' creato nel task corrente.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `git diff --stat` e `git diff --name-only`: perimetro coerente con TASK-047; nessun `project.pbxproj`, `Package.resolved`, Android, SQL/migration o config reale.
- ✅ ESEGUITO — Build Debug: PASS su iPhone 16e iOS 26.2 (`id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B`).
- ✅ ESEGUITO — Build Release: PASS sullo stesso simulator id.
- ✅ ESEGUITO — XCTest mirati: PASS (`SupabaseManualPushPreflightTests`, `SupabaseManualPushServiceTests`, `SupabasePushPreflightViewModelTests`, `LocalizationCoverageTests`).
- ✅ ESEGUITO — XCTest completo: PASS.
- ✅ ESEGUITO — Localizzazioni: `plutil -lint` PASS per IT / EN / ES / ZH-Hans.
- ✅ ESEGUITO — Scan segreti sul diff: PASS; nessun token/JWT/API key/secret/URL reale introdotto.
- ✅ ESEGUITO — Anti-scope scan: PASS; occorrenze `ProductPrice` solo come guardrail/test/localizzazione di esclusione.
- ✅ ESEGUITO — Warning nuovi: nessun warning Swift nuovo attribuibile al diff; presenti solo warning AppIntents metadata di toolchain/esistenti.
- ❌ NON ESEGUITO — Primo tentativo XCTest mirato con destination per nome `iPhone 16e`: non eseguito per ambiguita' runtime Xcode prima dell'avvio test; rieseguito con simulator id esplicito e PASS.
- ⚠️ NON ESEGUIBILE — Dry-run runtime live/local del dataset `TASK045_*`: volutamente non eseguito in TASK-047 per non trasformare la review in ripresa TASK-045; resta gate della futura ripresa TASK-045 con override utente.

### Rischi residui
- Il primo dry-run scoped sul dataset locale reale `TASK045_*` resta da eseguire in **TASK-045**, dopo nuovo override utente esplicito.
- Il rumore locale fuori prefisso resta nel database locale per design; TASK-047 lo esclude/conta/blocca quando necessario, non lo cancella.
- Codice privato legacy di conferma push resta non esposto dalla UI TASK-047; eventuale cleanup futuro e' fuori scope e non bloccante.

---

## Fix (Codex) ← vuoto

---

## Chiusura

### Esito finale
- **TASK-047** chiuso in **DONE / Chiusura** con esito review **APPROVED_FIXED_DIRECTLY / DONE**.
- **TASK-045** resta **BLOCKED** e non DONE; ripresa futura solo con nuovo override utente esplicito da collision check + dry-run scoped, non dal push diretto.
- Nessun push live, nessuna scrittura remota e nessun read-back live eseguiti in TASK-047.

### Follow-up candidate
- UUID whitelist run-specific se prefisso insufficiente dopo S47-01 *(eventuale microlavoro es. TASK-048).*
