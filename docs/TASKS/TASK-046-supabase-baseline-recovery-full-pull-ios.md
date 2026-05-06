# TASK-046: Supabase baseline recovery / full pull baseline iOS

## 1. Informazioni generali

- **Task ID**: TASK-046
- **Titolo**: Supabase baseline recovery / full pull baseline iOS
- **File task**: `docs/TASKS/TASK-046-supabase-baseline-recovery-full-pull-ios.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Tipo**: planning operativo / baseline recovery *(read-only verso Supabase, solo baseline/fingerprint locale)*
- **Responsabile attuale**: Claude / Planner
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05
- **Ultimo agente che ha operato**: Cursor / Planner *(creazione planning-only)*

## Dipendenze

- **TASK-045** — **BLOCKED** — validazione live manuale; ripresa da **T45-02** solo dopo baseline locale valida persistente.
- **TASK-044** — **DONE**
- **TASK-043** — **DONE** *(persistence baseline/fingerprint; preflight/push dipendono da baseline valida)*
- **TASK-040** — **DONE** *(full pull + bridge identità remota)*
- **TASK-038** — **DONE** *(Google Auth foundation)*

**Riferimenti Android / Supabase** *(contesto rischio, non perimetro iOS)*: **TASK-068** PARTIAL; **TASK-071** DONE, rischio `record_sync_event` / pattern sync — in TASK-046 restano **vietati** event sync, outbox, push, scritture remote.

---

## 2. Obiettivo

TASK-046 serve a **ottenere e persistere una baseline/fingerprint locale valida** dopo un **full pull read-only** (e, se necessario, **apply SwiftData solo locale** esplicito), così da sbloccare il prerequisito che oggi tiene **TASK-045** in **BLOCKED**.

Non è obiettivo di questo task validare **push live**, dataset `TASK045_*`, dry-run di push, read-back post-push, o idempotenza di scrittura: quello resta contratto **TASK-045** dopo il completamento di TASK-046.

---

## 3. Problema da risolvere

Situazione osservata (coerente con review **TASK-045** **APPROVED_FIXED_DIRECTLY_BLOCKED**):

- **Login Google** valido; **sessione Supabase** rilevata valida in UI DEBUG.
- **Baseline locale assente**: messaggio tipo **«Nessuna baseline salvata»** nella card DEBUG.
- Senza baseline valida, **TASK-043/TASK-044** non possono dare garanzie su **create / update / no-op**, collisioni e mapping; **TASK-045** deve quindi **fermarsi prima** di T45-03…T45-09 (dataset, collision check, preflight/push, read-back, ecc.).

TASK-046 colma **solo** questo gap: flusso sicuro **lettura remota + stato locale + salvataggio baseline** senza alcuna scrittura Supabase.

---

## 4. Matrice validazione proposta

| ID | Caso | Descrizione |
|----|------|-------------|
| **B46-01** | Config/Auth sessione valida | Verificare `SupabaseConfig.plist` reale solo macchina locale e ignorato da git; login Google valido; sessione non scaduta; UI DEBUG coerente. |
| **B46-02** | Full pull read-only | Eseguire fetch/paginazione completa catalogo (suppliers/categories/products come da implementazione TASK-040/035) **senza** POST/PATCH/DELETE/upsert RPC verso Supabase. |
| **B46-03** | Preview completezza | Verificare che il risultato non sia **partial**, senza **source errors** rilevanti, entro **budget/cap paginazione** documentato; altrimenti STOP — non salvare baseline. |
| **B46-04** | Apply locale controllato *(se necessario)* | Se la baseline richiede SwiftData allineata al preview (TASK-039): **apply solo locale**, con conferma UX se già previsto dal codice; **reversibile** via wipe/reset documentato o procedure team; **nessuna** scrittura remota. |
| **B46-05** | Baseline/fingerprint save | Persistere baseline **solo** dopo B46-03 (e B46-04 se applicabile) **OK**, usando il writer **TASK-043** (`SupabaseCatalogBaselineWriter` / path equivalente) senza aggiornamenti silenziosi parziali. |
| **B46-06** | Account/project consistency | Verificare che run baseline sia legato ad **account/progetto/schema** coerenti (no mismatch con sessione corrente; no baseline «di un altro tenant»). |
| **B46-07** | Restart persistence | Riavvio app/simulatore: baseline **latest valid** ancora leggibile; UI DEBUG **non** mostra «Nessuna baseline salvata». |
| **B46-08** | TASK-045 unblock check | Condizione necessaria per ripresa **TASK-045** da **T45-02**: baseline presente e considerata **valida** dal reader preflight; poi solo a quel punto dataset `TASK045_*`, collision check, dry-run. |
| **B46-09** | Anti-scope | Confermare assenza di: scrittura remota, push ProductPrice, `record_sync_event`, `sync_events`, outbox, sync auto/background/realtime, delete/tombstone outbound, SQL/RPC/RLS/migration, `service_role`. |

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

Micro-ritocchi opzionali in **OptionsView** sezione DEBUG Supabase:

- Rendere **più esplicito** lo stato baseline: *Assente* / *In corso* / *Valida* / *Partial/Bloccata*.
- Se baseline assente: testo breve + **azione guidata** del tipo *«Crea baseline da pull completo (solo lettura)»* che rimanda al flusso già esistente o al passo documentato in EXECUTION *(nessun nuovo wizard complesso)*.
- **SwiftUI** nativo: `Section`, `Form`, `ProgressView` durante pull, `alert` / `confirmationDialog` per conferme apply locale.
- Copy **breve**, chiaro, **localizzato** (IT/EN/ES/ZH-Hans come standard app); **nessuna** copia Android 1:1.

**Decisione UX documentata**: preferire **una riga di stato + secondary action** sotto la card baseline (es. `Button` stile `.borderedProminent` solo in DEBUG) piuttosto che nuove tab o flussi paralleli; stati allineati ai gate TASK-043 (`valid` vs assente/partial).

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

## Scopo *(riepilogo operativo)*

Ripristinare in modo **sicuro** e **tracciabile** la **baseline Supabase locale** tramite **full pull read-only** e salvataggio fingerprint, senza ampliare scope a push live o sync Android.

## Non incluso *(fuori scope tassativo)*

Come da istruzioni progetto + TASK-045: **nessun** push live; **nessuna** scrittura remota; **nessun** ProductPrice push; **nessun** `record_sync_event` / `sync_events` / outbox; **nessun** sync automatico/background/realtime; **nessuna** delete remota; **nessun** tombstone outbound; **nessun** SQL/RPC/RLS/migration; **nessun** `service_role`; **nessuna** modifica Android; **nessun** dataset `TASK045_*`; **nessun** dry-run/push TASK-045; **nessun** grande refactor; **nessuna** UI complessa nuova *(solo micro-ritocchi opzionali pianificati)*.

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

Definire un percorso **minimo** e **sicuro** per generare una **baseline valida** dopo **full pull read-only**, eventualmente **apply locale**, e **commit baseline** TASK-043, sbloccando **T45-02** senza eseguire il live push di TASK-045.

### Analisi

- **TASK-043** ha già modelli/run/record e writer/reader; la baseline **non compare** finché un percorso completo **pull (+ apply se necessario) → commit** non è stato eseguito con successo su device dell’utente.
- **TASK-045** è correttamente **BLOCKED** senza baseline: il problema è **operativo/runtime**, non necessariamente un difetto di push TASK-044.
- Rischio **Android TASK-071**: qualsiasi scivolamento verso event/outbox va escluso a priori nei gate anti-scope.

### Approccio proposto

1. Completare planning *(questo file)* e **review** planning / user override verso EXECUTION.
2. In EXECUTION: gate B46-01 → B46-02 → B46-03 → (B46-04) → B46-05 → B46-06/07 → B46-08/09.
3. Micro-fix Swift **solo** se necessario per chiarezza UX baseline o per bug bloccanti nel path read-only/baseline save; ogni fix ripassare REVIEW.
4. Al termine: handoff formale a **TASK-045** da **T45-02**.

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

- **Prossima fase**: EXECUTION *(solo dopo review planning OK + **user override** esplicito)*
- **Prossimo agente**: Cursor / Codex executor
- **Azione consigliata**: Eseguire i 7 blocchi del **§6**; aggiornare solo sezioni Execution/Handoff nel file task; non modificare MASTER-PLAN backlog/priorità salvo transizione di stato concordata.

---

## Execution (Codex)

*(Vuoto — non avviata.)*

---

## Review (Claude)

*(Vuoto — pending post-execution.)*

---

## Fix (Codex)

*(Vuoto.)*
