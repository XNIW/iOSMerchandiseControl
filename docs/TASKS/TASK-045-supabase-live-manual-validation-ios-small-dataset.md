# TASK-045: Supabase live manual validation iOS — push reale controllato supplier/category/products su dataset piccolo

## Informazioni generali
- **Task ID**: TASK-045
- **Titolo**: Supabase live manual validation iOS: push reale controllato supplier/category/products su dataset piccolo
- **File task**: `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- **Stato**: BLOCKED
- **Fase attuale**: — *(interrotta durante EXECUTION / dry-run scope gate)*
- **Responsabile attuale**: Utente / Claude *(serve decisione su candidati local-only non `TASK045_*` prima di qualsiasi push live)*
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05 23:57 -04 *(execution post-TASK-046 fermata al **dry-run scope gate**: baseline valida, dataset `TASK045_*` locale creato, collision check locale/baseline OK, ma il dry-run include anche candidati local-only non `TASK045_*`; **push live non eseguito**)*
- **Ultimo agente che ha operato**: Cursor / Codex executor
- **Nota ripresa**: Ripresa da **T45-02** dopo **TASK-046 DONE**; baseline valida disponibile. La ripresa e' stata eseguita gate-by-gate e si e' fermata prima del push perché il dry-run non era limitato al solo dataset `TASK045_*`.

## Dipendenze
- **Dipende da**:
  - **TASK-044** — **DONE / Chiusura** — push reale manuale controllato iOS (supplier / category / products baseline-gated); codice di riferimento per la validazione live.
  - **TASK-043** — **DONE** — baseline/fingerprint persistente; gate preflight/push.
  - **TASK-040** — **DONE** — full pull + remote identity bridge SwiftData.
  - **TASK-038** — **DONE** — Google Auth Supabase foundation.
  - **TASK-039 / TASK-041 / TASK-042** — **DONE** — apply locale, preflight/dry-run, UI DEBUG preliminare.
- **Riferimenti Android / Supabase** *(contesto e rischio, non contratto iOS 1:1)*:
  - **TASK-068** (**PARTIAL**) — bulk product push lato client presente; **ciclo B live** e validazione live bulk su delta reale ancora **pending** → validazione iOS resta **manuale, piccola, controllata**.
  - **TASK-071** (**DONE**) — rischio `record_sync_event` / `PayloadValidation` (es. `p_changed_count > 1000`) → in **TASK-045** è **vietato** usare `record_sync_event`, `sync_events`, outbox o sync automatico.
- **Sblocca**: confidence operativa su push live iOS; eventuali task futuri (ProductPrice, sync avanzato, ecc.) solo **fuori** da questo perimetro.

## Scopo
Validare **live**, in modo **manuale** e **controllato**, il push reale iOS già implementato in **TASK-044**, limitato a **supplier / category / product**, su **dataset piccolo**, **reversibile** e **documentato**, senza toccare backend SQL/RPC/RLS né validare su cataloghi grandi o dati non reversibili.

## Contesto obbligatorio
- Dopo **TASK-044** **DONE / Chiusura** il progetto era **IDLE**; con **TASK-045** il progetto è stato portato in **ACTIVE / EXECUTION** su user override, poi bloccato una prima volta per baseline assente. Dopo **TASK-046 DONE / Chiusura** la baseline è valida, ma la ripresa TASK-045 è ora **BLOCKED** al **dry-run scope gate** perché il piano include candidati local-only non `TASK045_*`.
- **TASK-039 / TASK-040 / TASK-041 / TASK-042 / TASK-043 / TASK-044** sono **DONE**.
- **TASK-044** ha implementato il push reale controllato, ma in sviluppo/review **non** è stato eseguito alcun **push Supabase live reale**.
- **TASK-045** è il **primo** task dedicato a **validazione live manuale controllata** del flusso iOS.
- **Android** è **riferimento funzionale**, non copia **1:1**.
- **Supabase locale** (schema/migration/progetto locale): solo per **nomi** tabella/colonna/constraint; **non** assume *locale = live* senza evidenza esplicita.
- UI di lavoro: sezione **DEBUG Supabase** già introdotta in **OptionsView** (TASK-042→044).

## Non incluso (fuori scope tassativo)
- Push o scrittura remota **ProductPrice**.
- **`record_sync_event`**, tabella **`sync_events`**, **outbox**, sync **automatico** / **background** / **realtime**.
- **Tombstone outbound**, **delete remota**.
- **SQL**, **RPC**, **RLS**, **trigger**, **migration** lato progetto Supabase.
- **`service_role`** o segreti elevati lato client.
- Modifiche **Android** o repo non-iOS.
- **Grande refactor** o ampliamento architetturale.
- Modifica **schema SwiftData** salvo quanto **già previsto** e **indispensabile** (da evitare; eventuale micro-fix solo se blocco TASK-044).
- Push su **dataset grande**.
- Test **distruttivi** su dati reali **non reversibili**.

## Dataset piccolo consigliato (reversibile)
Usare al massimo:
- **1** supplier nuovo di test
- **1** category nuova di test
- **1** product nuovo di test
- **1** product **esistente** modificato in modo **reversibile** *(ripristinare valore originale dopo il run o usare campo marcato test)*
- Opzionale: **1** caso **no-op / retry idempotente**

Naming esplicito *(esempi)*:
- supplier: `TASK045_SUPPLIER_TEST_<timestamp>`
- category: `TASK045_CATEGORY_TEST_<timestamp>`
- barcode prodotto nuovo: `TASK045_<timestamp>`

**Non** usare per il primo run dati critici del negozio.

---

## Matrice validazione live

| ID | Caso | Obiettivo verifica |
|----|------|-------------------|
| **T45-01** | **Config/Auth** | App con `SupabaseConfig.plist` **reale** presente **solo locale** (ignorato da git). Login Google valido, sessione non scaduta, UI DEBUG mostra account connesso. |
| **T45-02** | **Pull completo + baseline valida** | Eseguire pull completo/manuale se necessario; baseline/fingerprint **valida**; se assente/stale/partial → **push bloccato**. |
| **T45-03** | **Preflight no-write** | Dry-run su dataset piccolo; piano create/update/link coerente; **nessuna** scrittura remota prima della conferma. |
| **T45-04** | **Push reale manuale controllato** | Dopo conferma utente: scritture **solo** supplier/category/product; batch bounded/fallback come TASK-044; **nessun** ProductPrice; **nessun** record_sync_event/outbox. |
| **T45-05** | **Read-back remoto** | Dopo push, leggere da Supabase i record toccati; confermare `remoteID`/mapping; baseline «valid» **solo** dopo read-back riuscito (allineato TASK-044/043). |
| **T45-06** | **Idempotenza retry/no-op** | Ripetere preflight/push sullo stesso dataset; **no-op** o update controllato **senza duplicati**; niente merge silenzioso errato su supplier/category omonimi. |
| **T45-07** | **Guardrail negativo** | Se possibile senza corrompere dati: baseline stale/partial o account mismatch → **blocco sicuro** + microcopy chiara. |
| **T45-08** | **Pull post-push** | Dopo push, pull/preview; coerenza SwiftData locale ↔ remoto per i **record di test**. |
| **T45-09** | **Anti-scope grep** | Nessuna introduzione nel task di: `record_sync_event`, `sync_events`, `outbox`, push ProductPrice, delete remota, tombstone outbound, SQL/migration/RPC/RLS, `service_role`. |

---

## Criteri di accettazione
*(Contratto: execution e review lavorano contro questi criteri; evidenze **senza** segreti/token.)*

- [ ] **CA-01** — Build **Debug** PASS.
- [ ] **CA-02** — Build **Release** PASS, se già standard del progetto.
- [ ] **CA-03** — **XCTest** completo PASS.
- [ ] **CA-04** — Localizzazioni non rotte.
- [ ] **CA-05** — `git diff --check` PASS.
- [ ] **CA-06** — Nessun segreto tracciato in git.
- [ ] **CA-07** — `SupabaseConfig.plist` reale resta **ignorato** da git.
- [ ] **CA-08** — Push live eseguito **solo** dopo **conferma manuale** esplicita in UI.
- [ ] **CA-09** — Scritture remote limitate a **suppliers**, **categories**, **products**.
- [ ] **CA-10** — Nessun **ProductPrice** remoto creato/aggiornato dal flusso di test.
- [ ] **CA-11** — Nessun `record_sync_event`, `sync_events`, **outbox**.
- [ ] **CA-12** — Nessuna **delete remota** / tombstone **outbound**.
- [ ] **CA-13** — Nessun SQL/RPC/RLS/migration nel perimetro del task.
- [ ] **CA-14** — **Read-back remoto** conferma i record attesi (mapping coerente).
- [ ] **CA-15** — Baseline/fingerprint aggiornati **solo** dopo read-back **valido**.
- [ ] **CA-16** — **Retry** senza duplicazione dati inconsistente.
- [ ] **CA-17** — Errori / partial / account mismatch → blocco **sicuro** (no baseline finta).
- [ ] **CA-18** — Evidenze live documentate nel file task **senza** includere segreti/token.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|--------|
| 1 | Validazione **solo** live controllata su dataset **piccolo** | Test su catalogo grande o anonimo senza naming test | Riduce rischio; allineato vincolo utente e TASK-068 PARTIAL | attiva |
| 2 | **Vietato** `record_sync_event` / outbox / sync auto | Allineamento a pattern Android con event bus | Vincolo TASK-071 e istruzioni utente | attiva |
| 3 | **EXECUTION** solo con **user override** esplicito | Iniziare push live da planner | Policy sicurezza e workflow CLAUDE/AGENTS | attiva |
| 4 | Checklist operativa in sezione **neutra** «Planning refinement / User-requested integration» | Duplicare indefinitely in «Planning (Claude)» | Governance: refinement esplicitamente user-requested senza riscrivere Execution/Review/Fix | attiva |

---

## Planning refinement / User-requested integration

*(Sezione **neutra**: integrazione documentale richiesta dall’utente; **non** sostituisce le sezioni **Execution / Review / Fix**; fornisce la checklist **operativa consolidata** per la futura EXECUTION. La sezione **Planning (Claude)** sotto resta la fonte analitica originale; per i passi in ordine si usa questa checklist.)*

*Il planning documentale sotto (quattro blocchi, template evidenze, strategie di sicurezza) è **accettato come base operativa** dell’EXECUTION; **nessuna** duplicazione o riscrittura in questo turno.*

### Ambito di questo turno (solo planning — user requested)
- Questo turno è **solo** perfezionamento del **planning** (contenuto markdown nel file task +, se necessario, riallineamento **MASTER-PLAN** senza cambio di fase).
- **Nessuna** modifica Swift, **nessun** `project.pbxproj`, **nessun** `Package.resolved`.
- **Nessun** push live, **nessun** test live, **nessuna** modifica Supabase, **nessun** intervento su Android.
- La fase **EXECUTION** resta **bloccata** finché l’utente non concede **user override** esplicito (transizione **PLANNING → EXECUTION**).
- **Non** contrassegnare **TASK-045** come **DONE** da questo turno.

### Checklist EXECUTION futura — quattro blocchi *(efficienza e safety)*

*Si applica **solo dopo** user override esplicito verso EXECUTION.*

#### Blocco 1 — Pre-run safety gate
1. **`git status` pulito** — working tree controllato (evitare mix tra fix locali e prova live); branch noto.
2. **`SupabaseConfig.plist` reale** solo in macchina locale, **ignorato da git**; **mai** incollare plist o chiavi nel file task.
3. **Account Google** corretto per il tenant/progetto live concordato.
4. **Progetto Supabase live** confermato *(identità progetto senza segreti nel task)*.
5. **Dataset test** con **timestamp unico** pronto (prefisso `TASK045_*`, vedi § *Strategia dati test e rollback*).
6. **Collision check** *(prima di dry-run/push)* — verificare che **supplier name**, **category name** e **barcode** previsti (`TASK045_*` + `<timestamp>`) **non** esistano già in SwiftData/linea preflight coerente con quanto si andrà a creare; se risultano già presenti, **rigenerare il timestamp** oppure classificare esplicitamente come **retry / no-op intenzionale** (mai merge silenzioso su omonimi test). Registrare l’esito nel template evidenze (vedi riga *Pre push* in tabella).
7. **Baseline valida** e **pull completo** (o equivalente richiesto dal gate TASK-043/044) **prima** del push; se baseline assente, stale o partial → **STOP**.
8. **STOP** se config, account o baseline **non** sono ritenuti sicuri: registrare **BLOCKED** nel file task, non proseguire il live run.

#### Blocco 2 — Live run minimo
1. Eseguire **T45-01 → T45-06** sullo **stesso** dataset piccolo.
2. **Un solo** dataset piccolo nel primo ciclo; **un solo** push reale controllato (dopo conferma manuale esplicita).
3. **Subito dopo**: **retry / no-op** (preflight e, se previsto, secondo passaggio controllato) per **T45-06** — **senza** secondo dataset.
4. **T45-07** (guardrail negativo): solo se scenario **sicuro** e **reversibile**; altrimenti **SKIP** con motivazione.

#### Blocco 3 — Post-run verification
1. **Read-back remoto** (**T45-05**): verificare i record di test; strumenti **senza** `service_role`.
2. **Pull post-push** (**T45-08**): coerenza **SwiftData locale ↔ Supabase remoto** limitata ai record di test.
3. **Baseline / fingerprint**: considerati aggiornati in modo **valido** **solo** dopo read-back riuscito e coerente (CA-15).
4. Se read-back fallisce o l’allineamento non è dimostrato: **non** dichiarare baseline valida; usare **PARTIAL** / **BLOCKED** motivato.

##### Remote read-back strategy *(EXECUTION — solo record di test)*
- Il read-back remoto deve interrogare **solo** i record di test **`TASK045_*`** (nessun dump dell’intero catalogo).
- Usare **filtri mirati**: nome supplier test, nome category test, barcode test, e/o **suffix timestamp** concordato per il run.
- **Non** includere nel file task dati sensibili, export massivi, né log con token.
- **Non** usare `service_role`; usare **solo** il client Supabase **session-aware** già previsto dall’app (stessa sessione dell’utente autenticato).
- Se il read-back **non** riesce o non conferma i record attesi: **non** aggiornare né considerare **valida** la baseline; **non** dichiarare **DONE**.

#### Blocco 4 — Anti-scope + chiusura evidenze
1. **Grep / verifica statica** (**T45-09**): `record_sync_event`, `sync_events`, `outbox`, push **ProductPrice**, delete remota, tombstone outbound, introduzione SQL/RPC/RLS/migration, uso `service_role` nel perimetro del task.
2. Documentare **PASS / FAIL / BLOCKED / PARTIAL** per ogni caso/evidenza (vedi tabella sotto).
3. **Non** dichiarare **DONE** senza evidenza live **positiva** **oppure** **accettazione esplicita del gap** da parte dell’utente.

### Template evidenze live *(compilare in EXECUTION)*

| Caso | Stato | Evidenza richiesta | Note sicure |
|------|-------|-------------------|-------------|
| T45-01 | TODO / PASS / FAIL / BLOCKED | Screenshot UI DEBUG **senza** token; account **mascherato** | Niente segreti |
| Pre push | TODO / PASS / FAIL / BLOCKED | Esito **collision check** § Blocco 1 pt.6: assenza `TASK045_*` o ts rigenerato / retry dichiarato | No merge silenzioso su omonimi |
| T45-02 | TODO / PASS / FAIL / BLOCKED | Stato baseline / pull completo | Niente dump di catalogo sensibile |
| T45-03 | TODO / PASS / FAIL / BLOCKED | Conteggi dry-run create / update / link / no-op | Nessuna write remota prima della conferma |
| T45-04 | TODO / PASS / FAIL / BLOCKED | Conferma manuale + conteggi scrittura | Solo suppliers / categories / products |
| T45-05 | TODO / PASS / FAIL / BLOCKED | Read-back remoto record di test | No `service_role`; no JWT in chiaro |
| T45-06 | TODO / PASS / FAIL / BLOCKED | Retry / no-op senza duplicati | Idempotenza |
| T45-07 | TODO / PASS / FAIL / BLOCKED / SKIP | Blocco guardrail osservato | Solo se scenario sicuro |
| T45-08 | TODO / PASS / FAIL / BLOCKED | Pull post-push coerente | Confronto solo record di test |
| T45-09 | TODO / PASS / FAIL / BLOCKED | Esito grep / nota anti-scope | Nessun ampliamento di scope |

**Le evidenze non devono contenere:** token; JWT; URL con parametri segreti; email in chiaro se non indispensabili (preferire mascheramento); chiavi `service_role` o materiali equivalenti; dump completi del catalogo o export massivi di dati reali.

*(Per **CA-01…CA-03** (build/test): in EXECUTION registrare comandi ed esiti nel file task, **senza** log che contengano segreti.)*

### T45 → CA coverage *(sintesi review — non sostituisce la matrice né i CA)*

| Caso | CA coperti principali *(indicativi)* |
|------|----------------------------------------|
| T45-01 | CA-06, CA-07, CA-17 *(+ CA-01…CA-03 come gate tecnico a fine ciclo)* |
| T45-02 | CA-15, CA-17 |
| T45-03 | CA-08, CA-09, CA-17 |
| T45-04 | CA-08, CA-09, CA-10, CA-11, CA-12, CA-13 |
| T45-05 | CA-14, CA-15 |
| T45-06 | CA-16 |
| T45-07 | CA-17 |
| T45-08 | CA-14, CA-15 |
| T45-09 | CA-05, CA-06, CA-07, CA-10, CA-11, CA-12, CA-13 |

*Nota:* **CA-04** / **CA-18** restano trasversali (localizzazioni / qualità evidenze) e vanno considerati in review insieme alle righe template.

### Errori RLS / permission Supabase *(EXECUTION — decision tree)*

Se Supabase restituisce errore **RLS**, **permission denied**, **insert/select denied**, **account mismatch** o equivalente:

1. **Non** modificare SQL / RPC / RLS / migration nel perimetro TASK-045.
2. **Non** usare `service_role`.
3. Registrare nel task un **messaggio di errore mascherato** (codice/natura), **senza** token JWT o segreti.
4. Classificare almeno una causa probabile: **config/account errato**; **RLS live non allineata alle attese**; **drift schema live vs client**; **bug client iOS**; **dati test non validi**.
5. **Fermare** il run se non esiste un percorso sicuro senza uscire dallo scope.
6. Lasciare **TASK-045** in **BLOCKED** o **PARTIAL**; **mai** **DONE**.

### Strategia dati test e rollback
- Usare **solo** nomi con prefisso **`TASK045_`** (o convenzione equivalente registrata nello stesso task).
- Associare un **timestamp unico** al run (stesso suffisso su supplier / category / product di prova).
- **Preferire** creazione di record **nuovi** di test anziché alterare dati operativi reali.
- Se si modifica un **product esistente**: annotare **prima del push** i valori originali (campo per campo) per un eventuale ripristino manuale — **senza** riversare dati sensibili non necessari nel file task.
- **Non** utilizzare **delete remota** in **TASK-045**; nessun tombstone outbound.
- **Pulizia** dei record test remoti: pianificare come **task futuro separato**, oppure **lasciare** i record marcati test se accettabile per il team.
- Se il run degenera o non è possibile attestare sicurezza: **interrompere**; lasciare **TASK-045** **non DONE** con stato **BLOCKED** o **PARTIAL** documentato (sezione Execution).

### Regole UI/UX per eventuali micro-ritocchi *(solo in EXECUTION futura — non implementare ora)*
- **Ammessi** solo **micro-ritocchi** UI/UX se **necessari** allo sblocco della validazione o se **chiaramente migliorativi** per il flusso **DEBUG Supabase** in `OptionsView`, senza allargare il perimetro funzionale.
- **Tra alternative UX**, scegliere sempre la soluzione **più nativa iOS** e **coerente** con il resto dell’app.
- **Linee guida:** usare **Section**, **Form**, **List**, **`confirmationDialog`**, **`alert`**, **`ProgressView`** in stile SwiftUI idiomatico; rendere **distinti** i concetti **Dry-run**, **Push reale**, **Read-back**, **No-op**; il push reale deve essere una **scelta deliberata** (es. conferma esplicita con conteggi); copy breve e chiaro; evidenziare stati **Safe**, **Blocked**, **Partial**, **Done**; mostrare **conteggi prima** della conferma di scrittura; evitare UI rumorosa o **copia 1:1** dello stile Android; ogni modifica: **diff minimo**, coerente con `OptionsView`, stringhe in **localizzazioni** del progetto.

**Mini-proposta concreta (solo planning):** se in EXECUTION serve chiarire il flusso DEBUG in `OptionsView`, preferire una **progressione visiva a step** (ordine logico): **(1) Auth** → **(2) Baseline** → **(3) Dry-run** → **(4) Push reale** → **(5) Read-back** → **(6) No-op retry**; **badge/stati** coerenti (*Safe* / *Blocked* / *Partial* / *Done*); **pulsante push reale disabilitato** finché: login non valido; baseline non valida; dry-run non completato; piano con scope non ammesso; **`confirmationDialog`** prima del push con conteggi **suppliers / categories / products** (create / update / no-op per categoria); copy esplicito tipo **«Scrivi su Supabase Live»** (o chiave localizzata equivalente) invece di etichette ambigue; SwiftUI nativo coerente col resto dell’app; **nessun** layout Android copiato 1:1; **obbligatorie** localizzazioni per ogni stringa nuova.

### Criteri BLOCKED / PARTIAL — quando **non** dichiarare DONE

**TASK-045** resta **non DONE** se:
- Login **Google** fallisce o la **sessione** risulta scaduta / non rilevata.
- **Config live** non è confermata o è incerta.
- **Baseline** assente, **stale** o **partial**.
- Il **dry-run** mostra **scope** non previsto (oltre supplier/category/product controllato).
- Il flusso richiederebbe **ProductPrice**, **delete remota**, **tombstone**, **sync event** / outbox.
- Il **read-back remoto** **non** conferma i record attesi.
- Il **retry** genera **duplicati** o incoerenze.
- **RLS** live blocca letture/scritture in modo **non compreso** senza poter documentare un percorso sicuro **senza** SQL/RLS/migration.
- Manca **qualsiasi** evidenza live richiesta dalla matrice / tabella template.
- Servirebbero **SQL / RPC / RLS / migration** per andare avanti *(fuori scope — stop)*.

**Registrazione stato:**
- **BLOCKED** — non si può procedere in sicurezza finché non cambiano premesse o non c’è chiarimento esplicito.
- **PARTIAL** — alcuni **T45** risultano **PASS** ma manca evidenza **completa** o restano gap dichiarati.
- **DONE** — **mai** senza evidenza live positiva coerente con i CA **oppure** **accettazione esplicita del gap** da parte dell’utente.

### Comandi e check pianificati — **non eseguiti in PLANNING**

*La lista seguente è **solo** promemoria per **EXECUTION** / review; **in questo turno NON eseguire** questi comandi (nessuna build, nessun test, nessun grep obbligatorio ora).*

- `git status --short` (working tree controllato prima del live run)
- `git diff --check`
- Build **Debug** (CA-01)
- Build **Release** se resta standard del task corrente (CA-02)
- **XCTest** suite completa (CA-03)
- **Grep / verifica statica** anti-scope (allineata **T45-09**), indicativamente termini come: `record_sync_event`, `sync_events`, `outbox`, percorsi o chiamate che implichino **ProductPrice** push remoto, **delete** remota orchestrata, **tombstone** outbound, nuove **SQL** / **RPC** / **RLS** / **migration**, **`service_role`**

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Obiettivo (plan-level)
Eseguire la matrice **T45-01 … T45-09** contro il codice **TASK-044**, documentando esito e prove; applicare solo **micro-fix** iOS se emergono bug **bloccanti**, ciascuno piccolo, motivato e con test.

### Analisi
- Il push controllato è già in codebase (servizio push manuale, preflight, baseline TASK-043, UI DEBUG in `OptionsView`).
- Il **gap** attuale è **operativo**: manca evidenza **live** che confermi auth, gate baseline, dry-run, write limitata, read-back, aggiornamento baseline e idempotenza su Supabase **remoto** reale.
- **Android TASK-068** PARTIAL e **TASK-071** impongono prudenza: niente event sync/hook che possano esplodere vincoli lato DB o scope vietato.

### Approccio proposto
1. **PLANNING** *(questo task)*: raffinatezza operativa nella sezione **neutra** «Planning refinement / User-requested integration» + criteri nei CA; **zero** modifica Swift in PLANNING.
2. Dopo **user override** esplicito → **EXECUTION**: eseguire i **quattro blocchi** (pre-run, live minimo, post-verifica, anti-scope) su device/simulator con progetto Supabase **live** concordato; registrare esito per ogni **T45-xx** e **CA-xx**.
3. Se la validazione espone bug bloccante TASK-044: **micro-fix** + test mirato + rerun solo dei casi interessati.
4. Se push live non è **sicuro** (config, account, dati, RLS remoto non verificabile): lasciare task **non DONE**, documentare **blocco** e condizioni di sblocco.

### File da consultare (execution; nessun obbligo di modifica)
- `OptionsView` — sezione DEBUG Supabase (entrypoint preflight/push).
- Servizi push/preflight/baseline introdotti in catena **TASK-034 → TASK-044** (es. `SupabaseManualPushService`, `SupabasePushPreflightViewModel`, servizi pull/apply/baseline secondo nomi effettivi in repo).
- Modelli SwiftData con **remote identity** e campi baseline/fingerprint (**TASK-040 / TASK-043**).
- Test esistenti TASK-044 / regressione suite completa.

### Rischi identificati
| Rischio | Mitigazione |
|--------|-------------|
| Dati reali del negozio coinvolti per errore | Naming `TASK045_*` + vincolo quantità; rollback manuale documentato. |
| RLS remoto diverso da attese | Verificare read-back; se select bloccate, **non** dichiarare baseline valida; documentare. |
| Confusione locale vs live | Usare solo URL/progetto **live** dichiarato; non assumere stack locale come prova. |
| Tentazione scope creep (ProductPrice, events) | **T45-09** + code review grep a fine execution. |

### Piano execution — riferimento operativo
La sequenza **operativa** per EXECUTION (ordine dei passi, safety gate, live run minimo, post-verifica, anti-scope) è definita nella sezione **«Planning refinement / User-requested integration»** — **quattro blocchi** + **collision pre-push** + **remote read-back strategy** + **template evidenze live** + **T45→CA** + **albero errori RLS** + **strategia rollback** + **criteri BLOCKED/PARTIAL** + **regole UI/UX** / mini-proposta step + **comandi pianificati (non eseguiti in PLANNING)**.
*(Motivazione: checklist storica a 12 punti sostituita da struttura a 4 blocchi più efficiente; contenuto analitico Claude invariato nelle sottosezioni sopra.)*

### Handoff → Execution
- **Transizione 2026-05-05:** **EXECUTION** avviata su **user override** esplicito; responsabile operativo **Cursor / Codex executor** *(vedi sezione **Execution** per execution-start documentale; run live ancora da avviare)*.
- **Azione successiva (run reale):** eseguire la checklist a **quattro blocchi** nella sezione **«Planning refinement / User-requested integration»** (mapping **T45-01…T45-09**), compilare il **template evidenze live**, **CA-01…CA-18**; solo **micro-fix** / micro-ritocchi UI/UX per policy ivi definite; a fine run utile → **REVIEW** (Claude) con handoff aggiornato.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

> Nota: le prime sottosezioni Execution documentano i blocchi storici Auth/baseline. L’esito corrente dopo TASK-046 e' nella sottosezione **“Execution post-TASK-046 — BLOCKED al dry-run scope gate”**.

### Obiettivo compreso
Avviare la vera **EXECUTION controllata** di **TASK-045** in sequenza: safety gate → dry-run/preflight → push live manuale solo se tutti i gate sono verdi → read-back → retry/no-op → pull post-push → check finali → documentazione.
Il primo run si è fermato nel **Pre-run safety gate**. Il primo blocco Auth/passkey è stato risolto dall’utente; alla ripresa, la UI DEBUG ha confermato la sessione Google/Supabase, ma la baseline locale risultava assente (**"Nessuna baseline salvata"**). Per policy TASK-045 baseline assente = **STOP** prima di dataset/collision check/dry-run/push. Dopo TASK-046 la baseline e' stata ripristinata; il blocco corrente è documentato più sotto.

### File controllati
- `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`

### Piano minimo
1. Eseguire safety gate senza scrivere su Supabase.
2. Confermare config locale ignorata, assenza segreti/diff sospetti e app DEBUG installabile.
3. Verificare sessione Google valida dalla UI DEBUG Supabase.
4. Solo se sessione e baseline sono valide, preparare dataset `TASK045_*`, collision check e dry-run.
5. In caso di gate non sicuro: **STOP**, nessun workaround, tracking **BLOCKED**.

### Modifiche fatte
- Aggiornato tracking documentale TASK-045 a **BLOCKED** per safety gate non superato.
- Aggiornato `docs/MASTER-PLAN.md` coerentemente: **TASK-045 BLOCKED**, nessun task attivo.
- **Nessun** file Swift modificato.
- **Nessun** file Supabase/SQL/RPC/RLS/migration modificato.
- **Nessun** file Android modificato.
- **Nessun** dry-run/preflight eseguito.
- **Nessun** push live eseguito.
- **Nessun** read-back, retry/no-op o pull post-push eseguito.

### Evidenze live / T45
| Caso | Stato | Tipo verifica | Evidenza sicura |
|------|-------|---------------|-----------------|
| T45-01 | PASS | STATIC / BUILD / UI | `SupabaseConfig.plist` reale presente, ignorato da git, non tracciato; build Debug PASS; UI DEBUG mostra sessione Google/Supabase connessa. Account mascherato nel task. |
| Pre push | BLOCKED | STATIC / UI | Dataset `TASK045_20260506T021116Z` solo preparato come suffisso candidate; nessun record creato localmente/remotamente perché baseline gate non superato. Collision check remoto non eseguito. |
| T45-02 | BLOCKED | UI | Baseline/pull completo non valido: UI DEBUG mostra **Nessuna baseline salvata**. STOP prima del dry-run. |
| T45-03 | BLOCKED | UI | Dry-run/preflight non eseguito: STOP prima del dry-run. |
| T45-04 | BLOCKED | UI | Push live non eseguito. Nessuna conferma manuale di scrittura raggiunta. |
| T45-05 | BLOCKED | UI | Read-back remoto non eseguito perché nessuna scrittura è avvenuta. |
| T45-06 | BLOCKED | UI | Retry/no-op non eseguito perché il primo push non è avvenuto. |
| T45-07 | PASS | UI / PROCESS | Guardrail negativo osservato: baseline assente → run fermato senza workaround e senza push. |
| T45-08 | BLOCKED | UI | Pull post-push non eseguito perché nessun push è avvenuto. |
| T45-09 | PASS | STATIC | Diff fuori da `docs/` vuoto; nessuna modifica Swift/test/SQL/config. Grep su diff non-doc senza match per scope vietato (`record_sync_event`, `sync_events`, outbox, ProductPrice, delete, tombstone, SQL/RPC/RLS/migration, `service_role`). |

### CA-01…CA-18
| CA | Stato | Tipo verifica | Evidenza sicura |
|----|-------|---------------|-----------------|
| CA-01 | PASS | BUILD | `xcodebuild ... -configuration Debug ... build` PASS su iPhone 16e iOS 26.2. |
| CA-02 | NON ESEGUITO | BUILD | Build Release non eseguita: STOP al pre-run safety gate. |
| CA-03 | NON ESEGUITO | BUILD | XCTest completo non eseguito: STOP al pre-run safety gate. |
| CA-04 | PASS | STATIC | Nessun file di localizzazione modificato. |
| CA-05 | PASS | STATIC | `git diff --check` PASS; controllo whitespace no-index sul file task nuovo senza segnalazioni. |
| CA-06 | PASS | STATIC | Scan mirato su documenti modificati senza JWT/token/Bearer/URL Supabase/email completa; `SupabaseConfig.plist` reale resta ignorato e non tracciato. |
| CA-07 | PASS | STATIC | `SupabaseConfig.plist` presente localmente, `git check-ignore` PASS, `git ls-files --error-unmatch` conferma non tracciato, `git status --ignored` mostra `!!`. |
| CA-08 | BLOCKED | UI | Push live non raggiunto perché baseline assente. |
| CA-09 | BLOCKED | UI / STATIC | Nessuna scrittura remota eseguita; servizio letto staticamente limita il push manuale a supplier/category/product. |
| CA-10 | PASS | UI / STATIC | Nessun push eseguito; ProductPrice non usato nel run né introdotto dal diff. |
| CA-11 | PASS | UI / STATIC | Nessun push eseguito; `record_sync_event`, `sync_events`, outbox non usati nel run né introdotti dal diff. |
| CA-12 | PASS | UI / STATIC | Nessuna delete remota/tombstone outbound eseguita o introdotta dal diff. |
| CA-13 | PASS | STATIC | Nessun SQL/RPC/RLS/migration modificato o introdotto. |
| CA-14 | BLOCKED | UI | Read-back non eseguito. |
| CA-15 | BLOCKED | UI | Baseline/fingerprint post-read-back non verificati né aggiornati dal run. |
| CA-16 | BLOCKED | UI | Retry/no-op non eseguito. |
| CA-17 | PASS | PROCESS | Blocco sicuro applicato: nessun dry-run/push senza baseline valida. |
| CA-18 | PASS | DOC | Evidenze documentate senza token/JWT/chiavi/URL segreti/email completa. |

### Check eseguiti
- ✅ ESEGUITO — `git status --short`: worktree non pulito ma limitato a tracking documentale (`docs/MASTER-PLAN.md` modificato, file TASK-045 non tracciato prima dell’aggiornamento finale).
- ✅ ESEGUITO — Verifica `SupabaseConfig.plist`: presente, plist valido, ignorato da `.gitignore`, non tracciato da git, incluso nel bundle Debug.
- ✅ ESEGUITO — Shape config safety: URL HTTPS/non-local e key non-placeholder/non marcata server-only; valori non stampati.
- ✅ ESEGUITO — Scan mirato segreti su tracking diff/task: nessun pattern JWT/token/Bearer/URL Supabase/email completa ad alto rischio.
- ✅ ESEGUITO — Build Debug Simulator: PASS su iPhone 16e iOS 26.2.
- ✅ ESEGUITO — Conferma login Google/sessione valida: UI DEBUG mostra account Supabase connesso (mascherato nel task).
- ✅ ESEGUITO — Verifica baseline/pull completo: UI DEBUG mostra **Nessuna baseline salvata** → gate fallito.
- ❌ NON ESEGUITO — Dataset locale/remoto `TASK045_*`: non creato per stop baseline gate.
- ❌ NON ESEGUITO — Collision check remoto: non eseguito per stop baseline gate.
- ❌ NON ESEGUITO — Dry-run/preflight: non eseguito per stop baseline gate.
- ❌ NON ESEGUITO — Push live manuale: non eseguito.
- ❌ NON ESEGUITO — Read-back remoto: non eseguito.
- ❌ NON ESEGUITO — Retry/no-op: non eseguito.
- ❌ NON ESEGUITO — Pull post-push: non eseguito.
- ❌ NON ESEGUITO — Build Release: non eseguita perché il run è bloccato prima del live cycle.
- ❌ NON ESEGUITO — XCTest completo: non eseguito perché il run è bloccato prima del live cycle.
- ✅ ESEGUITO — `git diff --check`: PASS; file task nuovo controllato con `git diff --check --no-index` senza segnalazioni whitespace.
- ✅ ESEGUITO — Verifica statica anti-scope: diff fuori da `docs/` vuoto; grep su diff non-doc senza match per `record_sync_event`, `sync_events`, outbox, ProductPrice, delete, tombstone, SQL/RPC/RLS/migration, `service_role`.

### Rischi rimasti
- La validazione live vera non è stata eseguita.
- Baseline valida assente: serve pull/apply completo o chiarimento operativo prima di dry-run/push.
- Progetto live: config locale ha forma sicura e non-local; la sessione UI è connessa, ma il tenant/account resta da consolidare con baseline valida.
- Collision check, dry-run, push, read-back, retry/no-op e pull post-push sono tutti mancanti.
- Il task non è **DONE** e non è pronto per REVIEW di completamento live.

### Handoff post-execution *(blocco iniziale Auth — risolto dall'utente)*
**TASK-045** è stato inizialmente **BLOCKED** al **Pre-run safety gate**.

**Motivo blocco:** Google Auth richiede verifica passkey/secondo fattore dell’utente; Codex non può completarla né aggirarla in sicurezza.
**Esito successivo:** l’utente ha completato manualmente il login Google; la ripresa è documentata sotto. Il blocco corrente non è più Auth, ma **baseline assente**.

### Ripresa execution dopo sblocco utente
**2026-05-05 22:19 -04** — L’utente ha dichiarato di aver completato l’accesso Google. TASK-045 viene ripreso in **ACTIVE / EXECUTION** con responsabile **Cursor / Codex executor**. Ripartenza dal **Pre-run safety gate**: verificare sessione UI DEBUG, baseline/pull completo, dataset `TASK045_*`, collision check e dry-run prima di qualunque push live.

### Handoff post-execution *(BLOCKED — baseline assente)*
**2026-05-05 22:23 -04** — Pre-run safety gate ripreso dopo login utente.

**Esito:** sessione Google/Supabase visibile in UI DEBUG come connessa (account mascherato: `x***@gmail.com`), ma la sezione **Baseline Supabase locale** mostra **“Nessuna baseline salvata”**. Per istruzione TASK-045: baseline assente = **STOP** prima di dataset/collision check/dry-run/push.

**Azioni non eseguite per safety:**
- nessun dataset locale/remoto `TASK045_*` creato;
- nessun collision check remoto;
- nessun dry-run/preflight;
- nessun push live;
- nessun read-back, retry/no-op o pull post-push.

**Prossimo passo sicuro:** ottenere una baseline valida da pull/apply completo nel workflow previsto o ricevere istruzione esplicita di pianificazione/override che chiarisca come creare la baseline senza violare il gate. Poi riprendere TASK-045 da T45-02, non dal push.

### Ripresa execution post-TASK-046
**2026-05-05 23:30 -04** — Nuovo user override esplicito: **TASK-045** ripreso da **BLOCKED** a **ACTIVE / EXECUTION** con responsabile **Cursor / Codex executor**.

**Nota operativa:** TASK-046 e' **DONE / Chiusura**; la baseline Supabase locale valida e persistente e' ora disponibile. La ripresa parte da **T45-02** e dai gate corretti, non dal push live.

**Sequenza minima autorizzata:** safety gate aggiornato post-TASK-046 → verifica baseline valida → dataset piccolo `TASK045_*` → collision check remoto → dry-run/preflight → push live manuale controllato solo se tutti i gate sono verdi → read-back remoto filtrato → retry/no-op → pull post-push → build/test/check anti-scope → tracking.

**File previsti per modifica tracking:** `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`, `docs/MASTER-PLAN.md`.

### Execution post-TASK-046 — BLOCKED al dry-run scope gate
**2026-05-05 23:57 -04** — Run ripreso dai gate corretti dopo **TASK-046 DONE / Chiusura**. La baseline e' valida, il dataset piccolo e' stato preparato localmente, ma il dry-run non e' accettabile per TASK-045 perché include candidati local-only non `TASK045_*`. Per istruzione utente: **STOP** prima del push live.

#### Obiettivo compreso
Validare live TASK-045 solo su dataset piccolo `TASK045_*`, in ordine: safety post-TASK-046 → baseline valida → dataset test → collision check → dry-run → push live solo se tutti i gate sono verdi → read-back → retry/no-op → pull post-push → build/test/anti-scope. Il gate fallito e' **T45-03 dry-run/preflight** per scope non limitato al dataset test.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/Models.swift`

#### Piano minimo
1. Verificare safety/config/sessione/baseline senza scrivere su Supabase.
2. Creare un solo dataset locale `TASK045_*`.
3. Verificare collisioni locali e contro baseline remota persistente.
4. Eseguire dry-run/preflight.
5. Eseguire push live solo se il dry-run resta nel perimetro `TASK045_*` e supplier/category/products.
6. Fermarsi e tracciare BLOCKED se un gate non e' verde.

#### Modifiche fatte
- Aggiornato tracking di TASK-045 a **BLOCKED** per dry-run scope gate fallito.
- Aggiornato `docs/MASTER-PLAN.md` coerentemente: progetto **IDLE**, nessun task attivo, TASK-045 **BLOCKED**.
- Creato nel Simulator un dataset locale minimo `TASK045_*` per alimentare il dry-run; **nessuna scrittura remota**.
- **Nessun** file Swift modificato.
- **Nessun** micro-fix UI/UX applicato.
- **Nessun** push live eseguito.

#### Dataset usato
- Timestamp/suffisso: `20260506T034111Z`
- Supplier: `TASK045_SUPPLIER_TEST_20260506T034111Z`
- Category: `TASK045_CATEGORY_TEST_20260506T034111Z`
- Product barcode: `TASK045_20260506T034111Z`
- Product name: `TASK045_PRODUCT_TEST_20260506T034111Z`
- ProductPrice locale per dataset: `0` righe.

#### Evidenze live / T45
| Caso | Stato | Tipo verifica | Evidenza sicura |
|------|-------|---------------|-----------------|
| T45-01 | PASS | STATIC / UI | `SupabaseConfig.plist` reale presente solo locale, plist valido, ignorato e non tracciato; UI DEBUG mostra sessione Google/Supabase connessa con account mascherato. |
| Pre push | PASS | STATIC / UI | Collision check locale: supplier/category/barcode test assenti (`0/0/0`). Collision check su baseline remota persistente: supplier/category/barcode test assenti (`0/0/0`). Nessun merge silenzioso. |
| T45-02 | PASS | UI | Baseline post-TASK-046 valida e persistente visibile in UI DEBUG: ultimo pull completo `5 mag 2026, 23:06`, account coerente, prodotti `19697`, fornitori `59`, categorie `27`, schema fingerprint `1`, tombstone `0`. Non stale, non partial, non account mismatch. |
| T45-03 | FAIL | UI | Dry-run eseguito senza scrittura remota: scenario safe, blocchi `0`, warning `0`, future-only `0`; conteggi `2` supplier create, `3` category create, `1` product create. FAIL perché oltre al dataset TASK045 include candidati local-only non `TASK045_*`. |
| T45-04 | BLOCKED | UI / PROCESS | Push live **non eseguito**: gate T45-03 non verde. Nessuna conferma manuale di scrittura inviata. |
| T45-05 | BLOCKED | PROCESS | Read-back remoto non eseguito perché non c'e' stato push. |
| T45-06 | BLOCKED | PROCESS | Retry/no-op non eseguito perché il primo push e' stato bloccato. |
| T45-07 | PASS | PROCESS | Guardrail applicato: dry-run fuori perimetro dataset-only → stop sicuro prima del push. |
| T45-08 | BLOCKED | PROCESS | Pull post-push non eseguito perché non c'e' stato push. |
| T45-09 | PASS | STATIC | Anti-scope PASS: nessun diff Swift/Supabase/Android/SQL; nessuna introduzione operativa di ProductPrice push, `record_sync_event`, `sync_events`, outbox, delete remota, tombstone outbound, SQL/RPC/RLS/migration, `service_role`. |

#### CA-01…CA-18
| CA | Stato | Tipo verifica | Evidenza sicura |
|----|-------|---------------|-----------------|
| CA-01 | PASS | BUILD | Build Debug PASS su iPhone 16e iOS 26.2. Warning noto/toolchain AppIntents, non nuovo da diff codice. |
| CA-02 | PASS | BUILD | Build Release PASS su iPhone 16e iOS 26.2. Warning noto/toolchain AppIntents, non nuovo da diff codice. |
| CA-03 | PASS | BUILD | XCTest completo PASS (`** TEST SUCCEEDED **`) su iPhone 16e iOS 26.2. |
| CA-04 | PASS | STATIC | Nessun file UI/localizzazione modificato. |
| CA-05 | PASS | STATIC | `git diff --check` PASS. |
| CA-06 | PASS | STATIC | Scan mirato documenti modificati senza URL Supabase reale, JWT/token/Bearer o email completa. |
| CA-07 | PASS | STATIC | `SupabaseConfig.plist` reale ignorato da git e non tracciato. |
| CA-08 | BLOCKED | PROCESS | Push live non eseguito perché T45-03 e' fallito. |
| CA-09 | BLOCKED | PROCESS | Nessuna scrittura remota eseguita; dry-run avrebbe scritto solo supplier/category/product, ma non solo record TASK045. |
| CA-10 | PASS | STATIC / PROCESS | Nessun ProductPrice remoto creato/aggiornato; dataset locale senza righe ProductPrice. |
| CA-11 | PASS | STATIC / PROCESS | Nessun `record_sync_event`, `sync_events` o outbox usato o introdotto. |
| CA-12 | PASS | STATIC / PROCESS | Nessuna delete remota o tombstone outbound eseguita o introdotta. |
| CA-13 | PASS | STATIC | Nessun SQL/RPC/RLS/migration modificato o richiesto. |
| CA-14 | BLOCKED | PROCESS | Read-back remoto non eseguito perché push bloccato. |
| CA-15 | BLOCKED | PROCESS | Baseline/fingerprint post-read-back non aggiornati/confermati perché read-back non eseguito. |
| CA-16 | BLOCKED | PROCESS | Retry/no-op non eseguito perché push bloccato. |
| CA-17 | PASS | PROCESS | Blocco sicuro applicato su dry-run fuori perimetro: nessuna baseline finta, nessun workaround. |
| CA-18 | PASS | DOC | Evidenze documentate senza segreti/token/JWT/email completa/URL Supabase reale. |

#### Check eseguiti
- ✅ ESEGUITO — `git status --short`: worktree comprensibile; modifiche documentali attese su `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-045...md`, più `docs/TASKS/TASK-046...md` già modificato prima di questo run.
- ✅ ESEGUITO — `SupabaseConfig.plist`: plist valido, ignorato da `.gitignore`, non tracciato da git.
- ✅ ESEGUITO — Sessione Google/Supabase: UI DEBUG connessa, account mascherato nel task.
- ✅ ESEGUITO — Baseline post-TASK-046: valida/persistente in UI DEBUG, non partial/stale/account mismatch.
- ✅ ESEGUITO — Dataset `TASK045_*`: creato solo nello store locale Simulator con 1 supplier, 1 category, 1 product; ProductPrice locale `0`.
- ✅ ESEGUITO — Collision check locale: supplier/category/barcode test assenti prima della creazione.
- ✅ ESEGUITO — Collision check baseline remota persistente: supplier/category/barcode test assenti. Nota: una probe REST anonima corrente non e' stata usata come fonte perché non autenticata; nessun push e' stato eseguito.
- ✅ ESEGUITO — Dry-run/preflight: eseguito; esito **FAIL** per scope dataset-only, con conteggi documentati sopra.
- ❌ NON ESEGUITO — Push live manuale: bloccato dal dry-run scope gate.
- ❌ NON ESEGUITO — Read-back remoto: non eseguito perché nessun push.
- ❌ NON ESEGUITO — Retry/no-op: non eseguito perché nessun push.
- ❌ NON ESEGUITO — Pull post-push: non eseguito perché nessun push.
- ✅ ESEGUITO — Build Debug: PASS.
- ✅ ESEGUITO — Build Release: PASS.
- ✅ ESEGUITO — XCTest completo: PASS.
- ✅ ESEGUITO — Localizzazioni: nessuna stringa/UI modificata.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Scan segreti documentale: PASS.
- ✅ ESEGUITO — Anti-scope: PASS; nessuna nuova introduzione operativa di ProductPrice push, `record_sync_event`, `sync_events`, outbox, delete remota, tombstone outbound, SQL/RPC/RLS/migration, `service_role`.

#### Rischi rimasti
- Esistono candidati local-only preesistenti non `TASK045_*` nel dataset locale; il push manuale generico li includerebbe insieme al dataset test.
- Il dataset `TASK045_*` resta nello store locale Simulator; non e' stato scritto su Supabase.
- Il collision check corrente remoto autenticato non e' stato completato come query live separata; il check contro baseline remota persistente era pulito e il run si e' fermato comunque prima del push.
- Per procedere serve una decisione: pulire/gestire i candidati local-only preesistenti fuori TASK-045, oppure pianificare un filtro/debug flow scoped a `TASK045_*`. Non fare push silenzioso dell'intero piano.

#### Handoff post-execution *(BLOCKED — dry-run scope gate)*
**TASK-045** torna **BLOCKED**, non **DONE** e non passa a REVIEW di completamento live.

**Motivo blocco:** il dry-run/preflight e' no-write e tecnicamente senza blocker, ma il piano contiene `2` supplier create e `3` category create mentre il dataset TASK-045 autorizzato prevede `1` supplier, `1` category, `1` product. Procedere avrebbe scritto anche dati local-only non `TASK045_*`, violando la matrice dataset piccolo.

**Azioni non eseguite per safety:**
- nessun push live;
- nessun read-back remoto;
- nessun retry/no-op;
- nessun pull post-push;
- nessuna baseline/fingerprint post-read-back aggiornata;
- nessuna scrittura remota.

**Prossimo passo sicuro:** Claude/utente deve decidere come eliminare o isolare i candidati local-only non `TASK045_*`. Alla ripresa, ripartire da collision check e dry-run; non saltare direttamente al push.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Ambito review
Review tecnica severa **docs-only** delle modifiche Codex su TASK-045, limitata a:
- `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- `docs/MASTER-PLAN.md`

Nota governance: questa sezione è normalmente riservata a Claude. È compilata da Codex reviewer solo per **override esplicito dell'utente** in questa review.

### Esito review
**APPROVED_FIXED_DIRECTLY_BLOCKED**.

Lo stop di Codex al **Pre-run safety gate** è corretto: dopo login Google valido la UI DEBUG mostra sessione Supabase connessa, ma baseline/pull completo assente (**"Nessuna baseline salvata"**). Per contratto TASK-045, baseline assente = **STOP** prima di dataset `TASK045_*`, collision check remoto, dry-run/preflight, push live, read-back, retry/no-op e pull post-push.

TASK-045 resta quindi:
- **BLOCKED**
- **non DONE**
- non in review finale di completamento live
- progetto **IDLE**
- nessun task attivo

### File controllati
- `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- `docs/MASTER-PLAN.md`

### Fix applicati direttamente
- Compilata questa sezione **Review** con esito, ambito, verifiche, no-scope, rischi e prossimo passo sicuro.
- Riallineato `docs/MASTER-PLAN.md` con l'esito review **APPROVED_FIXED_DIRECTLY_BLOCKED** senza cambiare lo stato finale: TASK-045 resta **BLOCKED** e il progetto resta **IDLE**.
- Nessuna modifica a Swift, `project.pbxproj`, `Package.resolved`, Supabase, SQL/RPC/RLS/migration o Android.

### Verifiche eseguite
- ✅ ESEGUITO — `git status --short`: worktree limitato ai documenti attesi (`docs/MASTER-PLAN.md` e file task TASK-045).
- ✅ ESEGUITO — `git diff --check`: PASS sul diff tracciato; il file task nuovo è stato verificato anche con controllo no-index.
- ✅ ESEGUITO — controllo diff/scope: nessun file Swift, Supabase, Android, SQL/RPC/RLS/migration, `project.pbxproj` o `Package.resolved` modificato.
- ✅ ESEGUITO — anti-scope testuale sul diff: nessuna introduzione di `record_sync_event`, `sync_events`, outbox, push remoto ProductPrice, delete remota, tombstone outbound, SQL/RPC/RLS/migration o `service_role` fuori dalle citazioni documentali di divieto/controllo.
- ✅ ESEGUITO — controllo manuale segreti/dati sensibili nei documenti modificati: nessun token, JWT, Bearer token, URL Supabase reale o email completa; account eventualmente citato solo mascherato.
- ❌ NON ESEGUITO — Build Debug/Release/XCTest in questa review: non necessari perché review docs-only e nessun codice è stato modificato. La sezione Execution documenta già Build Debug PASS eseguita da Codex prima dello stop.

### Classificazione T45 / CA
- **T45-01 PASS** corretto: config/auth/sessione UI DEBUG verificate, senza esporre segreti.
- **Pre push, T45-02, T45-03, T45-04, T45-05, T45-06, T45-08 BLOCKED** corretto: dipendono dalla baseline valida e dal run live, mai raggiunti.
- **T45-07 PASS** corretto come guardrail negativo osservato: baseline assente → blocco sicuro senza workaround.
- **T45-09 PASS** corretto per review statica del diff e no-scope.
- **CA-01 PASS** corretto per Build Debug già documentata in Execution.
- **CA-02 / CA-03 NON ESEGUITO** corretto: Release/XCTest non necessari dopo stop al safety gate e non richiesti per questa review docs-only.
- **CA-04 / CA-05 / CA-06 / CA-07 / CA-10 / CA-11 / CA-12 / CA-13 / CA-17 / CA-18 PASS** corretti per evidenza statica/processuale.
- **CA-08 / CA-09 / CA-14 / CA-15 / CA-16 BLOCKED** corretti: push, read-back, baseline post-read-back e retry/no-op non sono stati eseguiti.

### Conferma no-scope
Confermato:
- nessun push live;
- nessun dry-run/preflight live;
- nessun read-back live;
- nessun retry/no-op;
- nessun pull post-push;
- nessun dataset `TASK045_*` creato localmente o remotamente;
- nessuna modifica Swift/Supabase/Android;
- nessun segreto o dato sensibile aggiunto ai documenti.

### Motivazione BLOCKED
Il blocco è intenzionale e sicuro. Procedere senza baseline valida violerebbe il gate TASK-043/TASK-044 e il contratto TASK-045, perché non sarebbe possibile distinguere in modo affidabile create/update/no-op, collisioni, mapping remoto e aggiornamento baseline post-read-back.

### Rischi residui
- La validazione live vera resta non eseguita.
- La baseline valida/pull completo manca ancora.
- Collision check remoto, dry-run/preflight, push live, read-back, retry/no-op e pull post-push restano senza evidenza.
- Eventuali micro-ritocchi UI/UX restano solo follow-up futuri e non sono stati implementati in questa review.

### Prossimo passo sicuro
Preparare un task separato per creare/ottenere una baseline valida in modo sicuro, oppure riprendere TASK-045 solo dopo baseline valida. Alla ripresa, ripartire da **T45-02** e non procedere direttamente a dry-run o push.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

*(Vuoto.)*

---

## Output atteso (riepilogo)
- File task **TASK-045** aggiornato con evidenze reali post-TASK-046: Auth/sessione PASS, baseline valida PASS, dataset `TASK045_*` locale creato, collision check locale/baseline PASS, dry-run eseguito ma fuori scope dataset-only → **BLOCKED**.
- `docs/MASTER-PLAN.md`: **TASK-045 BLOCKED**; **TASK-046 DONE / Chiusura**; **TASK-044** e **039–043** **DONE**; **TASK-032 / TASK-028** **BLOCKED**; progetto **IDLE** senza task attivo.
- **Nessuna** modifica Swift / Supabase / Android; dry-run/preflight eseguito no-write; **nessun** push live, read-back, retry/no-op o pull post-push.
- Alla ripresa: decidere come isolare o rimuovere i candidati local-only non `TASK045_*`, poi ripartire da collision check/dry-run; non procedere direttamente al push.
