# TASK-046: Supabase baseline recovery / full pull baseline iOS

## 1. Informazioni generali

- **Task ID**: TASK-046
- **Titolo**: Supabase baseline recovery / full pull baseline iOS
- **File task**: `docs/TASKS/TASK-046-supabase-baseline-recovery-full-pull-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Tipo**: planning operativo / baseline recovery *(read-only verso Supabase, solo baseline/fingerprint locale)*
- **Responsabile attuale**: Claude / Reviewer
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-06 *(REVIEW tecnica completata: Path B confermato, baseline locale valida e persistente, task chiuso DONE; TASK-045 resta BLOCKED/riattivabile da T45-02 solo con nuovo override utente)*
- **Ultimo agente che ha operato**: Codex / Reviewer *(review tecnica + fix tracking documentale)*
- **Nota transizione**: REVIEW → DONE / Chiusura; baseline locale valida presente; TASK-045 non DONE e non riaperto automaticamente

## Dipendenze

- **TASK-045** — **BLOCKED** — validazione live manuale; baseline locale ora presente/reviewata, ripresa da **T45-02** solo con nuovo override utente esplicito.
- **TASK-044** — **DONE**
- **TASK-043** — **DONE** *(persistence baseline/fingerprint; preflight/push dipendono da baseline valida)*
- **TASK-040** — **DONE** *(full pull + bridge identità remota)*
- **TASK-038** — **DONE** *(Google Auth foundation)*

**Riferimenti Android** *(rischio, non contratto iOS)*: TASK-068 PARTIAL; TASK-071 → **no** `record_sync_event`/outbox/sync come perimetro TASK-046 *(dettaglio divieti → § «Non incluso»)*.

---

## 2. Obiettivo

TASK-046 **ottiene e persiste** una baseline/fingerprint locale **valida**: **full pull read-only** verso Supabase, più — **solo se il codice lo impone** — **apply SwiftData esplicito** in locale, per sbloccare il prerequisito **T45-02**. Dopo la chiusura positiva di TASK-046, **TASK-045** resta **BLOCKED** nel tracking finché l'utente non autorizza una nuova ripresa esplicita da **T45-02**; TASK-046 **non** dichiara TASK-045 DONE. Push live, dataset `TASK045_*` e ciclo push TASK-045 restano **fuori** — dopo questo task.

Elenco **divieti operativi**: **§ Non incluso**.

---

## 3. Problema da risolvere

Situazione osservata (coerente con review **TASK-045** **APPROVED_FIXED_DIRECTLY_BLOCKED**):

- **Login Google** valido; **sessione Supabase** rilevata valida in UI DEBUG.
- **Baseline locale assente**: messaggio tipo **«Nessuna baseline salvata»** nella card DEBUG.
- Senza baseline valida, **TASK-043/TASK-044** non garantiscono create/update/no-op né mapping: **TASK-045** si ferma prima di T45-03…T45-09.

TASK-046 colma **solo** quel gap (**lettura remota + eventuale apply locale + baseline**) senza scrittura Supabase *(divieti: § Non incluso)*.

---

## 4. Matrice validazione proposta

| ID | Caso | Descrizione |
|----|------|-------------|
| **B46-01** | Config/Auth sessione valida | Verificare `SupabaseConfig.plist` reale solo macchina locale e ignorato da git; login Google valido; sessione non scaduta; UI DEBUG coerente. |
| **B46-02** | Full pull read-only | Eseguire fetch/paginazione completa catalogo (suppliers/categories/products come da implementazione TASK-040/035) **senza** POST/PATCH/DELETE/upsert RPC verso Supabase. |
| **B46-03** | Preview completezza | Verificare che il risultato non sia **partial**, senza **source errors** rilevanti, entro **budget/cap paginazione** documentato; altrimenti STOP — non salvare baseline. |
| **B46-04** | Apply locale controllato *(se necessario)* | Se serve SwiftData allineata (TASK-039): **apply solo locale**, **piccolo e tracciato**, solo dopo **preview completa** + conferma UX; **nessuna** scrittura remota; **no** wipe/reset «rapido» *(§ Local data safety)*. |
| **B46-05** | Baseline/fingerprint save | Persistere baseline **solo** dopo B46-03 (e B46-04 se applicabile) **OK**, usando il writer **TASK-043** (`SupabaseCatalogBaselineWriter` / path equivalente) senza aggiornamenti silenziosi parziali. |
| **B46-06** | Account/project consistency | Verificare che run baseline sia legato ad **account/progetto/schema** coerenti (no mismatch con sessione corrente; no baseline «di un altro tenant»). |
| **B46-07** | Restart persistence | Riavvio app/simulatore: baseline **latest valid** ancora leggibile; UI DEBUG **non** mostra «Nessuna baseline salvata». |
| **B46-08** | TASK-045 unblock check | Condizione necessaria per ripresa **TASK-045** da **T45-02**: baseline presente e considerata **valida** dal reader preflight; poi solo a quel punto dataset `TASK045_*`, collision check, dry-run. |
| **B46-09** | Anti-scope | Confermare assenza di: scrittura remota, push ProductPrice, `record_sync_event`, `sync_events`, outbox, sync auto/background/realtime, delete/tombstone outbound, SQL/RPC/RLS/migration, `service_role`. |

---

### Decisione baseline: full pull only vs apply locale

- **Prima di qualsiasi operazione runtime in EXECUTION:** leggere i **call path** (solo codice / documentazione): `SupabasePullPreviewService`, `SupabasePullApplyService`, `SupabaseCatalogBaselineWriter`, `SupabaseCatalogBaselineReader`, eventuali ViewModel o sezione DEBUG **`OptionsView`** che orchestrano pull / apply / baseline.
- **Path A (preferito):** con preview **completa**, il writer può persistere baseline **senza** mutare SwiftData → usare questo percorso se il codice lo supporta.
- **Path B:** se writer/reader richiedono SwiftData allineata → **apply locale** come **step separato** dal solo pull: preview **completa**; conteggi **create / update / no-op** (supplier, category, product); **nessun** conflitto/blocco bloccante; **conferma esplicita**; evidenza che durante il run **non** ci sono **scritture remote**.
- **Partial / source errors / stale / account mismatch:** nessun apply, nessun salvataggio baseline.
- **Vietato** baseline «finta», costruzione manuale seed, o aggiramento guardrail solo per sbloccare TASK-045.

---

### Template evidenze B46 *(futura EXECUTION / REVIEW)*

| Caso | Stato | Evidenza richiesta | Note |
|------|-------|-------------------|------|
| B46-01 | TODO / PASS / FAIL / BLOCKED | Sessione valida, config locale ignorata da git, shape config OK | Niente token |
| B46-02 | TODO / PASS / FAIL / BLOCKED | Pull read-only completato *(stato «completo», non partial)* | Niente dump catalogo |
| B46-03 | TODO / PASS / FAIL / BLOCKED | Stato partial/sourceErrors/cap o OK esplicito | **STOP** se incompleto |
| B46-04 | TODO / PASS / FAIL / BLOCKED / SKIP | Conteggi apply locale *(create/update/no-op per supplier/category/product, conflitti)* se apply usato; altrimenti SKIP motivato | Solo SwiftData locale |
| B46-05 | TODO / PASS / FAIL / BLOCKED | Baseline/fingerprint salvati; ID run o stato UI coerente | Solo dopo pull *(+ apply se richiesto)* valido |
| B46-06 | TODO / PASS / FAIL / BLOCKED | Account/progetto/schema coerenti *(mascherati)* | No mismatch |
| B46-07 | TODO / PASS / FAIL / BLOCKED | Baseline persiste dopo restart; UI DEBUG aggiornata | Cold start |
| B46-08 | TODO / PASS / FAIL / BLOCKED | TASK-045 riprendibile da **T45-02**; nessun salto al push | Handoff documentato |
| B46-09 | TODO / PASS / FAIL / BLOCKED | Anti-scope PASS *(grep/static review)* | Zero scritture remote |

**Le evidenze non devono contenere:** token; JWT; URL Supabase reale; email in chiaro; dump/export di catalogo; `service_role`; dati sensibili operativi del negozio.

---

### Copertura Review: B46 → CA46

*(Mappa indicativa per review futura; CA46-01…03 trasversali a build/test.)*

| Caso | CA46 coperti principali |
|------|-------------------------|
| B46-01 | CA46-05, CA46-06 |
| B46-02 | CA46-07, CA46-08 |
| B46-03 | CA46-07, CA46-10 |
| B46-04 | CA46-08, CA46-10 |
| B46-05 | CA46-10 |
| B46-06 | CA46-10, CA46-11 *(coerenza metadati run ↔ persistenza)* |
| B46-07 | CA46-11 |
| B46-08 | CA46-12, CA46-13 |
| B46-09 | CA46-04, CA46-05, CA46-08, CA46-09 |

---

### Partial / cap / pagination policy

- Una baseline è **valida** solo se il pull (e l’eventuale preview su cui si fonda il writer) è **completo** secondo i guardrail del codice — non **partial**.
- Se preview/pull è **partial** o con **source errors** bloccanti: **non** salvare baseline; classificare **BLOCKED** o **PARTIAL** con motivazione.
- Se il **cap** o il **pagination budget** documentato in codice impedisce la **completezza** del catalogo necessaria alla baseline: **STOP** — TASK-046 **BLOCKED** / **PARTIAL**; **non** «aggiustare» il catalogo con baseline approssimativa.
- In EXECUTION: **vietato** aumentare arbitrariamente cap/budget «per far passare» il run. Qualsiasi **micro-fix** a costanti di paginazione/budget deve essere **solo read-side**, **motivato**, coperto da **test** e review — niente baseline **«best effort»** o **„abbastanza buona“**.

---

### Local data safety / rollback locale

- TASK-046 **non** modifica Supabase; l’**apply SwiftData** può **alterare dati locali** sul device.
- **Wipe/reset locale** **non** è soluzione rapida in TASK-046: va **evitato** salvo **istruzione esplicita dell’utente**, **procedura team** concordata, o **task separato** dedicato — mai come escamotage per «sbloccare» il run.
- **Apply locale** (path B): solo se **necessario**, **perimetro minimo**, **tracciato** in evidenze; **obbligatoria** **preview completa** prima dell’apply.
- **Prima dell’apply**, documentare stato minimo *(senza dati sensibili in chiaro)*: conteggi **supplier / category / product**; baseline preesistente sì/no; riferimento **preview/piano**.
- Apply **fallito a metà** o stato locale **ambiguo** → **STOP**, TASK-046 **PARTIAL** o **BLOCKED**; **non** salvare baseline «a tentativi».
- Non usare TASK-046 per «pulire» dati locali **non correlati** al pull/baseline.
- **Rollback** locale solo se **pianificato** in EXECUTION, **mai** improvvisato; nessuna procedura distruttiva documentata qui.

---

## 5. Criteri di accettazione

*(Contratto futuro per EXECUTION/REVIEW; non verificati nel turno di creazione planning-only.)*

- [ ] **CA46-01** — Build **Debug** PASS.
- [ ] **CA46-02** — Build **Release** PASS, se standard corrente del progetto.
- [ ] **CA46-03** — **XCTest** completo PASS, se codice modificato o se resta standard obbligatorio per il task.
- [ ] **CA46-04** — `git diff --check` PASS.
- [ ] **CA46-05** — Nessun segreto tracciato in git.
- [ ] **CA46-06** — `SupabaseConfig.plist` reale ignorato da git e non incluso in evidenze sensibili.
- [ ] **CA46-07** — Full pull completato senza stato **partial** / **source errors** che impediscono baseline valida.
- [ ] **CA46-08** — Nessuna scrittura remota Supabase nel perimetro del task.
- [ ] **CA46-09** — Nessun ProductPrice push remoto, nessun `record_sync_event` / outbox / `sync_events`, nessuna delete/tombstone outbound.
- [ ] **CA46-10** — Baseline/fingerprint salvati **solo** dopo stato completo valido (nessun «commit» su preview incompleto).
- [ ] **CA46-11** — Baseline persistente dopo restart (coerente con reader **latest valid**).
- [ ] **CA46-12** — **TASK-045** resta **BLOCKED** finché TASK-046 non è completato e reviewato positivamente *(non si usa TASK-046 per dichiarare TASK-045 DONE)*.
- [ ] **CA46-13** — Dopo TASK-046, prossimo passo operativo documentato: **ripresa TASK-045 da T45-02** — **non** saltare direttamente al push live.

---

### Entry gates per futura EXECUTION

**Non** è previsto che Cursor/Codex avvii **EXECUTION** subito dopo un refinement planning-only: il **primo passo consigliato** resta la **review planning documentale con Claude** (§ Handoff). Cursor/Codex può avviare **EXECUTION TASK-046** solo se:

- **Review planning** con Claude **completata con esito favorevole** *oppure* **accettazione esplicita** utente sul piano *(equivalente documented)*.
- **User override** esplicito **PLANNING → EXECUTION**.
- **`git status`** controllato *(contesto di lavoro noto)*.
- Conferma: perimetro **read-only verso Supabase** *(nessuna scrittura remota, nessun push live)*.
- **TASK-045** **non** è ripreso in parallelo come task in **EXECUTION** *(resta **BLOCKED**)*.
- Conferma: **nessun push live** nel perimetro TASK-046.
- **Apply SwiftData** *(se previsto)* è **distinto** dal solo pull e richiede **decisione esplicita** nel run (path B § Decisione baseline), con evidenza **zero scritture remote**.

*(Sezione planning-only; non avvia EXECUTION.)*

---

## 6. Piano operativo futuro *(solo planning — blocchi EXECUTION)*

1. **Pre-run safety gate** — `git status`; config plist locale/ignorata; auth/sessione; URL/progetto concordato senza esporre segreti; conferma **nessun** obiettivo di scrittura remota.
2. **Full pull read-only** — Usare servizi esistenti (es. `SupabaseInventoryService`, `SupabasePullPreviewService`) in modalità **solo lettura**; paginazione fino a completezza o STOP esplicito se cap/budget.
3. **Eventuale apply locale controllato** — Se richiesto dal flusso TASK-039: `SupabasePullApplyService` / conferma UI DEBUG; rollback pianificato se fallimento.
4. **Save baseline/fingerprint** — `SupabaseCatalogBaselineWriter` + modelli TASK-043; verifica assenza errori writer (`partialPreview`, `sourceErrorsPresent`, conflitti, ecc.).
5. **Restart verification** — Chiusura app / cold start; `SupabaseCatalogBaselineReader` / UI DEBUG confermano baseline.
6. **Anti-scope checks** — Grep/review diff: divieti CA46-09; nessun file Supabase/SQL/Android fuori perimetro.
7. **Handoff a TASK-045** — Aggiornare tracking: TASK-045 **BLOCKED →** riattivabile su **EXECUTION** solo con user override; ripartenza obbligatoria **T45-02**; MASTER-PLAN allineato.

---

## 7. UI/UX *(planning only — non implementare in questo turno)*

Micro-ritocchi opzionali in **OptionsView** sezione DEBUG Supabase, **solo** se in futura EXECUTION migliorano chiarezza senza nuovo wizard:

**Stati baseline leggibili** *(label + eventuale icona/SF Symbol leggero)*:

- **Assente** — nessun run valido; CTA principale disponibile se gate OK.
- **Pull in corso** — operazione attiva; pulsanti di mutazione disabilitati.
- **Preview completa** — pull OK, pronto per writer o per apply *(se il path lo richiede)*.
- **Apply locale richiesto** — enfatizza che la prossima azione tocca **solo SwiftData** locale.
- **Baseline valida** — allineato a reader `latest valid` / run **valid**.
- **Bloccata / Partial** — mismatch, partial, cap, errori fonte; copy che indica STOP, non «salva comunque».

**CTA DEBUG proposta** *(stringhe da localizzare)*:

- Titolo bottone: **«Crea baseline da pull completo»**
- Sottotitolo o footnote: **«Solo lettura Supabase»** *(chiarisce assenza di push)*

**Disabilitare il bottone** se: login non valido; sessione scaduta; `SupabaseConfig` assente/errato; **pull/baseline già in corso** *(reentrancy)*.

**Interaction:**

- **`ProgressView`** durante full pull *(e durante apply locale se lungo)*.
- **`confirmationDialog`** **solo** quando serve confermare **apply SwiftData** locale *(con riepilogo conteggi create/update/no-op per supplier/category/product se disponibile)*.
- **`alert`** per errori bloccanti o partial non recuperabili.

**Vincoli:** copy breve; localizzazioni obbligatorie per ogni stringa nuova; **nessuna** copia Android 1:1; **nessun** wizard multi-step nuovo; layout coerente con `Form`/`Section`/`List` già usati in **Opzioni**.

**Decisione UX documentata:** una **card baseline** con **titolo stato** + **sottotesto** + **un solo pulsante primario** (*Crea baseline…*) mantiene il DEBUG compatto; eventuale seconda riga per «Applica in locale» o conferma resta subordinata al path codice *(full-pull-only vs apply-richiesto)*.

**Decisione finale (planning):** in EXECUTION, Cursor sceglie autonomamente la variante più coerente con l’app: **SwiftUI nativo**, allineata a **OptionsView**, **una sola CTA primaria**, copy breve, **distinzione chiara** tra *pull read-only* / *apply SwiftData locale* / *baseline valida* / *blocked·partial*, **nessun wizard complesso**, **localizzazioni obbligatorie** per ogni stringa nuova.

*In **questo** turno: **nessun** codice UI; eventuali micro-ritocchi saranno **valutati solo** in futura EXECUTION, con le stesse linee guida.*

---

## 8. Quando fermarsi

TASK-046 va considerato **BLOCKED** o **PARTIAL** *(non DONE)* se:

- Login/sessione non valida o incerta.
- Config live non confermabile senza ambiguità.
- Pull remoto fallisce (rete, auth, errori API).
- Pull classificato **partial** o con **source errors** bloccanti.
- Paginazione/cap impedisce completezza **documentata** come richiesta per baseline.
- **RLS** o permessi bloccano letture necessarie al full pull — **nessun** workaround con `service_role` o SQL nel perimetro TASK-046.
- Account/progetto **mismatch** rispetto ai metadati baseline previsti.
- Baseline **non persiste** dopo restart o reader non vede run **valid**.
- Servirebbe SQL/RPC/RLS/migration o qualsiasi **scrittura remota** per procedere.
- Rischio **segreti** o spill di dati sensibili nelle evidenze.

---

## 9. Output atteso *(fine futura EXECUTION + REVIEW)*

- Baseline locale **valida** e **persistente** leggibile da UI DEBUG e reader preflight.
- **Zero** scrittura remota nel perimetro task.
- **TASK-045** pronto a ripartire da **T45-02** con handoff esplicito *(non da push)*.
- File task TASK-046 aggiornato (Execution/Review); **MASTER-PLAN** allineato (stato TASK-046, TASK-045 ancora BLOCKED fino a chiusura validazione live).

---

## 10. Comandi e check pianificati — **non eseguiti in PLANNING**

*(Promemoria per futura **EXECUTION** / review; **in questo turno e nella fase PLANNING corrente non eseguire** questi comandi.)*

**Repository / testo:**

- `git status --short`
- `git diff --check`

**Build / test** *(quando il task avanza in EXECUTION e se tocca codice):*

- Build **Debug**
- Build **Release** se resta standard del progetto
- **XCTest** completo se codice modificato o se CA46-03 applicabile

**Sicurezza config / segreti:**

- Verifica `SupabaseConfig.plist` reale presente solo in locale e **ignorato** da git *(es. `git check-ignore`, non `cat` del plist nel task)*

- Scan mirato su **documenti/evidenze** del task per assenza token/JWT/URL live/email complete

**Anti-scope statico** *(indicativamente grep / review diff sul perimetro del task):*

- `record_sync_event`
- `sync_events`
- `outbox`
- push remoto **ProductPrice**
- delete remota orchestrata
- tombstone **outbound**
- nuove **SQL** / **RPC** / **RLS** / **migration**
- `service_role` lato client

---

## Non incluso *(fuori scope — divieti operativi)*

- **No push live**; **no scritture remote** Supabase; **no ProductPrice** push remoto.
- **No** `record_sync_event`, `sync_events`, **outbox**; **no** sync auto / background / realtime; **no** delete remota né **tombstone outbound**.
- **No** SQL / RPC / RLS / migration progetto; **no** `service_role` client.
- **No** modifiche **Android**; **no** dataset **`TASK045_*`**; **no** dry-run/preflight **push** TASK-045 come sostituto di questo task; dopo TASK-046 **no** salto diretto al push (→ CA46-13, ripresa **T45-02**).
- **No** grande refactor; UI solo **micro-ritocchi** opzionali (§7).

## File potenzialmente coinvolti *(EXECUTION — riferimento)*

*(Solo lettura in PLANNING; elenco basato sulla codebase iOS attuale.)*

- `OptionsView.swift` — DEBUG Supabase, stato baseline, entry pull/apply.
- `SupabaseAuthService.swift`, `SupabaseAuthViewModel.swift` — sessione Google / `authStateChanges`.
- `SupabaseClientProvider.swift`, `SupabaseConfig.swift` — client session-aware, hardening config.
- `SupabaseInventoryService.swift`, `SupabasePullPreviewService.swift` — fetch paginato read-only, preview.
- `SupabasePullApplyService.swift`, `SupabasePullPreviewModels.swift` — apply locale, guardrail partial/errors.
- `SupabaseCatalogBaselineWriter.swift`, `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineModels.swift` — persistenza baseline TASK-043.
- `SupabasePushPreflightViewModel.swift` / servizi preflight — verifica gate `blockedMissingBaseline` / stale *(solo lettura stato)*.
- Test mirati esistenti catena TASK-039/040/043 se toccati da fix minimi.

---

## Planning (Claude)

### Obiettivo (plan-level)

Come **§2**: percorso **minimo e sicuro** verso baseline valida (pull read-only ± apply locale + commit TASK-043), senza live push TASK-045. Dettaglio operativo **§4–§6**, CA **§5**.

### Analisi

- **TASK-043** ha già modelli/run/record e writer/reader; la baseline **non compare** finché un percorso completo **pull (+ apply se necessario) → commit** non è stato eseguito con successo su device dell’utente.
- **TASK-045** è correttamente **BLOCKED** senza baseline: il problema è **operativo/runtime**, non necessariamente un difetto di push TASK-044.
- Il percorso **full pull only** vs **apply poi baseline** dipende dal contratto effettivo del writer/reader: vedi **§4 — Decisione baseline**.
- **Partial/cap:** §4 *Partial / cap / pagination policy*; **dati locali / rollback:** §4 *Local data safety*.
- Rischio **Android TASK-071**: qualsiasi scivolamento verso event/outbox va escluso a priori nei gate anti-scope.

### Approccio proposto

1. **Primo passo:** **review planning documentale con Claude** (o responsabile planning) — questo micro-refinement **non** abilita da solo l’EXECUTION. Esito **non** è **DONE** task *(§ Review)*.
2. **EXECUTION** (Codex/Cursor): solo dopo passo 1 OK **e** **user override** esplicito **e** **Entry gates**; sequenza B46 → §6.
3. Micro-fix Swift solo se necessario; ogni fix → **review post-exec** reale.
4. Chiusura: handoff **T45-02**; **TASK-045** resta **BLOCKED** finché TASK-046 non è **completato e reviewato** (non solo planning).

### File coinvolti

Vedi sezione **File potenzialmente coinvolti** sopra.

### Rischi identificati

| Rischio | Mitigazione |
|--------|-------------|
| Catalogo remoto troppo grande vs budget | Documentare STOP partial; non forzare baseline «finta». |
| RLS select diverso da attese | STOP; nessun SQL client task; escalation fuori TASK-046. |
| Confusione account multipli | Verificare B46-06 su ID utente/progetto coerenti con sessione. |
| Scope creep verso push | CA46-12/13 + grep anti-scope B46-09. |

### Criteri di accettazione

Allineati alla sezione **§5** (CA46-01 … CA46-13).

### Handoff

- **Prossimo passo consigliato:** **review planning documentale con Claude**; **non** avviare **EXECUTION** senza **user override** esplicito **successivo** al planning OK. Questo refinement **non** autorizza Codex/Cursor a partire in EXECUTION da soli.
- **Review planning**: esito sul piano; **non** equivale a **DONE** task *(§ Review)*.
- **EXECUTION**: solo dopo **Entry gates** *(post-CA, pre-§6)* + override utente; agente tipico Cursor / Codex executor.
- **In EXECUTION:** blocchi **§6**; aggiornare sezioni Execution/Handoff; MASTER-PLAN solo su cambio stato/fase concordato.

*Nota 2026-05-05: **EXECUTION** avviata con user override (**transition-only**). Per **prossimo passo operativo** e handoff aggiornati → **§ Execution (Codex)** — *Handoff post-transition*.*

*Execution start (2026-05-05): il planning §2–§10 *(matrici B46/CA46, Entry gates, policy, local data safety, UI planning, comandi pianificati, Non incluso)* è accettato come **base operativa** dell’EXECUTION — nessun duplicato in questo turno.*

---

## Execution (Codex)

### Obiettivo compreso

Ottenere una baseline/fingerprint Supabase locale reale e persistente tramite full pull sicuro, senza scritture remote, per rendere **TASK-045** riprendibile in futuro da **T45-02**. Esecuzione consentita dall'istruzione utente esplicita: read-only verso Supabase; apply SwiftData solo locale se richiesto dal codice; nessun push live.

### File controllati

- `docs/TASKS/TASK-046-supabase-baseline-recovery-full-pull-ios.md`
- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineModels.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`

### Piano minimo eseguito

1. Safety gate: `git status --short`, config plist locale ignorata, sessione/UI DEBUG valida, TASK-045 non riaperto.
2. Lettura call path reali: preview, apply, writer/reader baseline, auth/config, UI DEBUG.
3. Full pull read-only via UI DEBUG `Preview dry-run Supabase`.
4. Decisione Path B: writer/reader baseline usano SwiftData locale, non il payload remoto del preview.
5. Apply SwiftData locale dopo preview completa e conferma UI.
6. Commit baseline/fingerprint via `SupabaseCatalogBaselineWriter`.
7. Verifica reader/UI e cold start.
8. Build/test/check anti-scope e aggiornamento tracking.

### Path scelto

**Path B — full pull read-only → preview completa → apply locale SwiftData → baseline/fingerprint.**

Motivo: `SupabaseCatalogBaselineWriter.commitAfterSuccessfulFullPullApply(...)` valida il preview ma costruisce i fingerprint leggendo `Product`, `Supplier` e `ProductCategory` dal `ModelContext`; non esiste nel codice corrente un Path A che persista una baseline completa direttamente dal payload remoto senza SwiftData allineata.

### Evidenze runtime

- Config: `iOSMerchandiseControl/SupabaseConfig.plist` reale presente solo localmente, `plutil -lint` OK, ignorato da git via `.gitignore`; non e' tracciato in `git ls-files`.
- Sessione/progetto: UI DEBUG autenticata e azioni Supabase abilitate; nessun URL, token, JWT o email completa riportati nel tracking.
- Full pull read-only completato da preview: `Prodotti remoti 19698`, `Fornitori remoti 80`, `Categorie remote 43`, `Nuovi 19697`, `Candidati aggiornamento 0`, `Conflitti 0`, `Tombstone remoti 1`.
- Completezza: preview finale non mostrava stato partial; apply abilitato, quindi guardrail codice superati (`preview.outcome == .success`, `sourceErrors.isEmpty`, no `priceHistoryIncomplete`, no conflitti).
- Conferma apply locale: `confirmationDialog` mostrato con copy "solo database locale SwiftData / non scrive su Supabase / non elimina prodotti locali".
- Apply locale: `Applicato localmente: 19697 nuovi, 0 aggiornati`.
- Baseline writer: `Baseline salvata: 19697 prodotti, 59 fornitori, 27 categorie`.
- Reader/UI prima e dopo cold start: stato baseline **Baseline attiva**, schema fingerprint `1`, conteggi persistenti `19697 / 59 / 27`, `Tombstone 0`; la UI DEBUG non mostra piu' "Nessuna baseline salvata".
- Persistenza: eseguito `xcrun simctl terminate` + `xcrun simctl launch`; dopo riapertura la baseline resta leggibile.

Nota su lookup remoti: il full pull ha letto 80 fornitori e 43 categorie; l'apply locale esistente materializza nel database locale solo i lookup necessari/allineati ai prodotti applicati. La baseline valida del reader copre quindi il catalogo locale applicato: 59 fornitori e 27 categorie.

### Modifiche fatte

- Nessun file Swift modificato.
- Nessun plist/progetto/Package/SQL/RPC/RLS/migration modificato.
- Nessuna modifica Android.
- Runtime locale SwiftData modificato tramite apply esplicito Path B: creati/allineati localmente i record necessari al catalogo pull.
- Tracking aggiornato in questo file e in `docs/MASTER-PLAN.md`.

### Matrice B46

| Caso | Stato | Evidenza |
|------|-------|----------|
| B46-01 | PASS | `git status --short` controllato; config reale locale ignorata e `plutil` OK; UI DEBUG autenticata senza riportare segreti. |
| B46-02 | PASS | Full pull read-only completato via `SupabasePullPreviewService`; codice usa `select` + `range`, nessun metodo di scrittura. |
| B46-03 | PASS | Preview completa/non partial; apply abilitato solo dopo guardrail preview success/sourceErrors/conflicts/priceHistory. |
| B46-04 | PASS | Path B necessario; apply locale confermato via dialog; prodotti create/update = `19697/0`; fornitori/categorie baseline finale `59/27`; nessuna scrittura remota. |
| B46-05 | PASS | Baseline salvata tramite `SupabaseCatalogBaselineWriter` dopo preview completa + apply locale. |
| B46-06 | PASS | Reader/UI associato ad account corrente mascherato; nessun mismatch UI; nessun URL/key/JWT documentato. |
| B46-07 | PASS | Cold start con terminate/launch: baseline ancora attiva e conteggi invariati. |
| B46-08 | PASS | TASK-045 resta BLOCKED ma prerequisito baseline e' ora presente; ripresa futura da T45-02 documentata. |
| B46-09 | PASS | Anti-scope statico/diff: nessun push live, nessuna scrittura remota, nessun SQL/RPC/RLS/migration, nessun service_role. |

### CA46

| Criterio | Stato | Evidenza |
|----------|-------|----------|
| CA46-01 | PASS | Build Debug Simulator PASS (`xcodebuild ... Debug build`). |
| CA46-02 | PASS | Build Release Simulator PASS (`xcodebuild ... Release build`). |
| CA46-03 | PASS | XCTest completo PASS (`xcodebuild test`, `** TEST SUCCEEDED **`). |
| CA46-04 | PASS | `git diff --check` PASS. |
| CA46-05 | PASS | `SupabaseConfig.plist` non tracciato; grep file tracciati solo su riferimenti/documenti/example/test, nessun secret file reale. |
| CA46-06 | PASS | Config reale presente solo localmente e ignorata da git; valori non riportati. |
| CA46-07 | PASS | Pull completo/non partial, nessun source error bloccante, preview abilitata all'apply. |
| CA46-08 | PASS | Nessuna scrittura remota Supabase nel task. |
| CA46-09 | PASS | Nessun ProductPrice push remoto, `record_sync_event`, outbox, `sync_events`, delete remota o tombstone outbound. |
| CA46-10 | PASS | Baseline salvata solo dopo preview completa e apply locale completato. |
| CA46-11 | PASS | Baseline persistente dopo cold start e leggibile da reader/UI latest valid. |
| CA46-12 | PASS | TASK-045 resta BLOCKED; non e' stato riaperto ne' marcato DONE. |
| CA46-13 | PASS | Prossimo passo documentato: REVIEW TASK-046, poi eventuale ripresa TASK-045 da T45-02 con override esplicito. |

### Check eseguiti

- ✅ ESEGUITO — `git status --short`: working tree comprensibile; solo tracking docs modificati.
- ✅ ESEGUITO — `plutil -lint iOSMerchandiseControl/SupabaseConfig.plist`: OK, senza stampare valori.
- ✅ ESEGUITO — `git check-ignore -v iOSMerchandiseControl/SupabaseConfig.plist`: ignorato da `.gitignore`.
- ✅ ESEGUITO — lettura call path reali: preview/apply/writer/reader/UI/config/auth.
- ✅ ESEGUITO — full pull read-only: completato, non partial.
- ✅ ESEGUITO — apply locale SwiftData Path B: completato dopo conferma, nessuna scrittura remota.
- ✅ ESEGUITO — baseline writer/reader: writer confermato; UI reader mostra baseline attiva.
- ✅ ESEGUITO — restart persistence: terminate/launch, baseline ancora presente.
- ✅ ESEGUITO — Build Debug Simulator: PASS.
- ✅ ESEGUITO — Build Release Simulator: PASS. Nota: Xcode ha emesso il warning metadata/AppIntents gia' noto di toolchain, non collegato a modifiche Swift (nessun codice Swift modificato).
- ✅ ESEGUITO — XCTest completo: PASS.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — anti-scope statico: nessuna modifica Swift/Supabase/Android/SQL/RPC/RLS/migration; nessun uso `service_role`; nessun dataset `TASK045_*`.

### Rischi rimasti

- La baseline e' valida per il reader/preflight locale, ma **TASK-045 resta BLOCKED** finche' TASK-046 non riceve review positiva e l'utente non autorizza la ripresa.
- Il writer attuale non crea baseline direttamente da snapshot remoto: se in futuro serve coprire anche lookup remoti non materializzati localmente (80/43 remoti vs 59/27 locali), va pianificato come follow-up separato.
- Il full pull storico prezzi e' stato lungo; non ho introdotto cap/budget arbitrari per accorciarlo.
- Le evidenze UI/Computer Use hanno mostrato dati account/catalogo sullo schermo durante la run; nel tracking non sono riportati email completa, URL, token, JWT o dump catalogo.

### Handoff post-execution

**TASK-046** passa a **ACTIVE / REVIEW**. Baseline locale valida e persistente ottenuta tramite **Path B**; nessuna scrittura remota; nessun push live; nessun `ProductPrice` push, `record_sync_event`, `sync_events`, outbox, delete remota, tombstone outbound, SQL/RPC/RLS/migration o `service_role`.

**Handoff a Claude / Reviewer:** verificare coerenza del Path B e delle evidenze B46/CA46. Se review positiva, TASK-046 potra' essere chiuso solo secondo workflow progetto; **TASK-045** resta **BLOCKED** fino a completamento/review positiva di TASK-046 e dovra' essere ripreso in futuro da **T45-02**, non dal push live.

---

## Review (Claude)

### Esito

**APPROVED_FIXED_DIRECTLY / DONE**

Review tecnica severa completata su override esplicito utente. Fix diretto applicato **solo documentale/tracking**: compilata questa sezione Review, chiuso TASK-046 in **DONE / Chiusura**, allineato `docs/MASTER-PLAN.md`.

### File verificati

- `docs/TASKS/TASK-046-supabase-baseline-recovery-full-pull-ios.md`
- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineModels.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/OptionsView.swift` *(call path baseline/apply verificato staticamente, nessuna modifica)*

### Valutazione tecnica

- **Path B confermato corretto.** `SupabaseCatalogBaselineWriter.commitAfterSuccessfulFullPullApply(...)` valida il preview ma poi costruisce i fingerprint leggendo `Product`, `Supplier` e `ProductCategory` da SwiftData locale tramite `ModelContext`. Non risulta un Path A completo che salvi una baseline/fingerprint direttamente dal payload remoto senza SwiftData allineata.
- **Apply locale coerente col piano.** L'apply e' stato uno step esplicito, locale SwiftData, dopo preview completa e conferma UI. Non e' una scrittura remota e non equivale a push live.
- **Baseline non finta/non manuale.** La baseline risulta prodotta dal writer esistente e riletta dal reader/UI come latest valid, con persistenza dopo cold start.
- **Mismatch lookup remoto/local baseline non bloccante.** Il full pull ha letto `19698` prodotti remoti, `80` fornitori, `43` categorie e `1` tombstone remoto; l'apply locale ha materializzato `19697` prodotti correnti e il writer ha salvato baseline per `19697` prodotti, `59` fornitori, `27` categorie, `0` tombstone. Questo e' coerente col contratto attuale: il writer fingerprinta il catalogo SwiftData locale applicato e include lookup con `remoteID` effettivamente materializzati/necessari ai prodotti locali. I lookup remoti non referenziati dai prodotti applicati e il tombstone remoto non materializzato restano fuori dalla baseline locale corrente. Follow-up non bloccante: se in futuro serve baseline completa anche per lookup remoti non materializzati o tombstone remoti non locali, pianificarlo come task separato.
- **B46/CA46 accettati.** Le evidenze dichiarate coprono B46-01...B46-09 e CA46-01...CA46-13. Per B46-04, la review accetta il PASS perché sono documentati product insert/update, conferma UI e conteggi finali writer/reader per lookup; non serve retrocedere il task per l'assenza di un conteggio separato supplier/category create nella sezione Execution.
- **TASK-045 non chiuso e non riaperto.** TASK-045 resta **BLOCKED**; dopo questa review positiva diventa il prossimo candidato riattivabile da **T45-02**, solo con nuovo user override esplicito.

### Controlli eseguiti in Review

- ✅ ESEGUITO — `git status --short`: solo `docs/MASTER-PLAN.md` e questo file task modificati.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `git diff --stat`: solo i due file documentali/tracking.
- ✅ ESEGUITO — `git diff --name-only`: nessun file Swift, progetto Xcode, Supabase runtime, Android, SQL/RPC/RLS/migration, `Package.resolved` o plist modificato.
- ✅ ESEGUITO — verifica call path Swift: writer/reader/apply confermano Path B e baseline da SwiftData locale.
- ✅ ESEGUITO — anti-scope diff/statico: nessuna introduzione operativa di push live, scritture remote, ProductPrice push, `record_sync_event`, `sync_events`, outbox, sync automatico/background/realtime, delete remota, tombstone outbound, SQL/RPC/RLS/migration, `service_role`, Android, dataset `TASK045_*`, wipe/reset locale.
- ✅ ESEGUITO — scan documentale segreti: nessun token/JWT/API key/URL Supabase reale/email completa/dump catalogo nei due file modificati; ricorrenze trovate solo come divieti o note di sicurezza.
- ✅ ESEGUITO — `git ls-files iOSMerchandiseControl/SupabaseConfig.plist`: nessun file tracciato.
- ✅ ESEGUITO — `git check-ignore -v iOSMerchandiseControl/SupabaseConfig.plist`: ignorato da `.gitignore`.
- ✅ ESEGUITO — `plutil -lint iOSMerchandiseControl/SupabaseConfig.plist`: OK, senza stampare valori.
- ⚠️ NON RIESEGUITO — Build Debug: gia' PASS in Execution; review solo documentale, nessun codice/progetto modificato.
- ⚠️ NON RIESEGUITO — Build Release: gia' PASS in Execution; review solo documentale, nessun codice/progetto modificato.
- ⚠️ NON RIESEGUITO — XCTest completo: gia' PASS in Execution; review solo documentale, nessun codice/progetto modificato.

### Rischi residui / follow-up

- **TASK-045** resta **BLOCKED** per workflow: baseline ora valida, ma la ripresa richiede nuovo override utente e deve partire da **T45-02**.
- La baseline copre il catalogo locale applicato; eventuale esigenza futura di includere lookup remoti non materializzati o tombstone remoti non locali va trattata fuori TASK-046.
- Nessun redesign UI/UX, nessun micro-fix Swift e nessuna operazione Supabase aggiuntiva eseguiti in review.

### Chiusura

TASK-046 chiuso in **DONE / Chiusura**. Baseline locale valida e persistente confermata; nessuna scrittura remota; nessun push live; TASK-045 resta **BLOCKED**, non **DONE**, ed e' solo riattivabile come prossimo candidato da **T45-02** con nuovo override esplicito.

---

## Fix (Codex)

*(Vuoto.)*
