# TASK-101 — Production readiness privacy / RLS / security audit

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-101** |
| **Titolo** | **Production readiness privacy / RLS / security audit** |
| **File task** | `docs/TASKS/TASK-101-production-readiness-privacy-rls-security-audit.md` |
| **Stato task** | **ACTIVE** |
| **Fase attuale** | **PLANNING** |
| **Responsabile attuale** | **Claude / Planner** |
| **Data creazione** | 2026-05-10 |
| **Ultimo aggiornamento** | 2026-05-10 — **Inizializzazione planning** (solo markdown) |

**TASK-101 NON DONE.**

**NON READY FOR EXECUTION** — nessuna autorizzazione implicita; execution (read/audit runtime, eventuali write Supabase, modifiche RLS/SQL) solo dopo Planning Review esplicita, consenso utente, Go/No-Go §10 e handoff verso **EXECUTION**.

**Handoff turno corrente:** **READY FOR PLANNING REVIEW**

**Flag:** **`TASK-101_PLANNING_INIT_ONLY`** — creato **solo** questo file task + tracking MASTER; **zero** Swift/Kotlin/SQL/backend/build/test/runtime/Supabase in questo turno; **nessuna** apertura **TASK-102**; **nessun** claim DONE o production-ready 100%.

---

## 2. Contesto

| Riferimento | Ruolo per TASK-101 |
|-------------|-------------------|
| **TASK-100** | Appena chiuso **DONE / Chiusura — REVIEW PASS FINAL** (2026-05-10): acceptance grande dataset, live Supabase sintetico, cleanup scoped; contesto **performance/UX** e **42501** su delete `authenticated` già spiegato nelle evidenze *(cleanup risolto con admin/postgres senza cambiare policy/grant)*. |
| **TASK-038** | Ha stabilito **Google Auth foundation** iOS; TASK-101 deve verificare coerenza auth/session con RLS e owner. |
| **TASK-091…TASK-100** | Serie sync manuale/semi-auto, ProductPrice, conflict/recovery, cross-platform, sandbox/runtime, large dataset — tutti usano o toccano **Supabase**, **RLS**, **live/test data**, **cleanup** e **performance**; TASK-101 formalizza un **audit** prima di readiness dichiarazioni più ampie. |
| **TASK-099** | Conflict/recovery, distinzione auth vs permission/RLS, CTA e failure mode — input per audit failure mode e leak UX. |
| **TASK-097 / TASK-098** | Sandbox e smoke cross-platform con owner redatto, no `service_role` in app — baseline comportamento atteso. |
| **TASK-102** | **Non aperto** in questo turno: resta **TODO / Planning — non aperto**, nessun file task. |

---

## 3. Obiettivo

1. **Definire** un audit di **production-readiness** focalizzato su: **privacy**, **RLS**, **sicurezza Supabase**, **owner scoping**, **auth/session**, **secret handling**, **logging e evidenze privacy-safe**, **policy cleanup/test data**, **failure modes**, **least privilege**, **uso service_role/admin**, **sicurezza write live**, **data retention**, **coerenza cross-platform** (iOS / Android / Supabase).
2. **Non** dichiarare **production-ready globale 100%** alla fine del solo planning né confondere planning con esito audit.
3. **Separare** esplicitamente: **planning** (questo documento) → **audit statico** / **Supabase schema & policy review** (read-only salvo override) → **verifica runtime** (dove autorizzata) → **remediation opzionale** (task/follow-up separati, non impliciti in TASK-101 se fuori scope).

---

## 4. Non-obiettivi / vietati in questo planning-init

- **Nessuna** modifica **Swift / Kotlin / SQL / migration / RLS / policy / grant**.
- **Nessun** **Supabase write**, **cleanup live**, o **DDL** da questo init.
- **Nessun** **build/test** obbligatorio o esecuzione runtime per completare TASK-101 in questo turno.
- **Nessuna** apertura **TASK-102** (nessun file task, nessun planning TASK-102).
- **Nessuna** dichiarazione **TASK-101 DONE**.
- **Nessun** claim **production-ready 100%** globale.
- **Nessuna** modifica a `Localizable.strings`, `project.pbxproj`, o repo Android salvo task futuro esplicito.

---

## 5. Fonti da leggere in futura EXECUTION *(repo-grounded)*

Ordine suggerito (non attivo finché NON READY FOR EXECUTION non diventa false dopo gate utente):

1. **Supabase:** progetto locale / clone `MerchandiseControlSupabase`, **migrations**, policy RLS, grants, eventuali funzioni/trigger citati nei task 085/086/088+.
2. **iOS:** configurazione Supabase, auth Google/Supabase, session refresh, Keychain/plist (senza committare segreti).
3. **iOS sync:** `SupabaseManualSync*` e percorsi Release; apply/preview; guard owner/session.
4. **ProductPrice:** servizi apply/push/dedupe, idempotenza, read-back.
5. **Evidenze** `docs/TASKS/EVIDENCE/TASK-097` … `TASK-100` (matrici, manifest, privacy notes, decision log).
6. **Android repo** (riferimento): parity auth/owner/RLS expectations; **non** obbligatorio per ogni slice iOS-only se non in scope.
7. **Google auth / Supabase Auth** configurazione documentata e codice client.
8. **Log / evidenze:** note privacy TASK-100 e pattern grep anti-segreto usati nei task precedenti.

---

## 6. Micro-slice pianificate **S101-A … S101-K**

| ID | Titolo | Output atteso (post-review / EXECUTION futura) |
|----|--------|-----------------------------------------------|
| **S101-A** | Preflight repo / schema / evidence | Inventario path codice+SQL+evidence; branch/commit; lista gap rispetto a TASK-097…100. |
| **S101-B** | Supabase RLS / grants / policy inventory | Tabella policy per tabella/ruolo; `authenticated` vs `anon` vs `service_role`; azioni SELECT/INSERT/UPDATE/DELETE. |
| **S101-C** | Owner scoping audit | Ogni tabella sensibile: filtro `owner_user_id` (o equivalente) nelle policy; fail-closed documentato. |
| **S101-D** | Auth / session / token handling audit | Dove vivono token, refresh, logout, binding sessione→owner; niente `service_role` in app. |
| **S101-E** | service_role / admin usage audit | Chi usa ruolo elevato, in quali script/CI/operator run; vincoli e rotazione; divieto nel binario consumer. |
| **S101-F** | Logging / secrets / privacy evidence audit | Grep + review log: niente JWT, connection string, barcode/account reali nelle evidenze. |
| **S101-G** | Live write / delete safety audit | Quando write live è ammesso; prefissi test; collision scan; rollback narrative. |
| **S101-H** | Cleanup / test data retention policy | Ciclo di vita dati `TASK*` / sandbox; chi può cancellare cosa; retention e GDPR-oriented notes. |
| **S101-I** | iOS / Android / Supabase parity security checks | Stesso owner semantics; nessuna divergenza silenziosa su auth/scope. |
| **S101-J** | Risk matrix + remediation routing | R101 mappati a azioni: document-only, task backend, task client, BLOCKED. |
| **S101-K** | Final readiness decision | Esito **PASS / PARTIAL / BLOCKED** per area (non slogan globale). |

---

## 7. Matrice acceptance **M101-01 … M101-12**

Stato iniziale di ogni riga: **PLANNED / NOT RUN**.

| ID | Area | Verifica prevista | Evidenza prevista | Stato iniziale | PASS | PARTIAL | BLOCKED |
|----|------|-------------------|-------------------|----------------|------|---------|---------|
| **M101-01** | Preflight | Repo + migrations + evidence TASK-097…100 letti e indicizzati | Note in `MANIFEST.md` / preflight | PLANNED / NOT RUN | Indice completo | Un repo non disponibile ma workaround documentato | Repo/DB non ispezionabili |
| **M101-02** | RLS inventory | Policy complete per tabelle inventory/sync rilevanti | `rls-policy-inventory.md` | PLANNED / NOT RUN | Coerente con least privilege | Buchi documentati con piano | Permessi non ispezionabili |
| **M101-03** | Grants / ruoli | Ruoli DB e grant allineati a policy | `grants-audit.md` | PLANNED / NOT RUN | Nessun surplus per anon | Correzioni pianificate senza esecuzione in planning | Grants caotici |
| **M101-04** | Owner scope | Row-level owner su dati tenant | `owner-scope-matrix.md` | PLANNED / NOT RUN | Owner ovunque necessario | Eccezioni giustificate | Scoping assente/ambiguo |
| **M101-05** | Auth session | Sessione JWT/refresh; logout; invalidazione | `auth-session-audit.md` | PLANNED / NOT RUN | Coerente con RLS | Edge case documentati | Token handling non reviewabile |
| **M101-06** | service_role | Mai in app client; solo tool operativi controllati | `secrets-scan-notes.md` + inventario | PLANNED / NOT RUN | Zero in binario iOS/Android consumer | Uso tooling documentato | service_role richiesto dall’app |
| **M101-07** | Delete/update policy | Coerenza tombstone/delete vs cleanup test (es. TASK-100 lesson) | Policy doc + note | PLANNED / NOT RUN | Delete test operabile con ruoli attesi | Cleanup solo admin documentato | DELETE implausibile senza piano |
| **M101-08** | Live write safety | Write solo con prefisso/scope/consenso | `live-write-safety-audit.md` | PLANNED / NOT RUN | Scope chiaro | Write limitate a script | Write live non governate |
| **M101-09** | Logging privacy | Log senza PII/secrets | `logging-privacy-audit.md` | PLANNED / NOT RUN | Redazione verificata | PII minima redatta | Secrets in log |
| **M101-10** | Retention / cleanup | Policy dati test e retention | `cleanup-retention-policy.md` | PLANNED / NOT RUN | Linee guida chiare | Solo dev/staging coperto | Nessuna policy |
| **M101-11** | Cross-platform parity | Owner/auth coerenti iOS/Android | `android-ios-security-parity.md` | PLANNED / NOT RUN | Allineato | PARTIAL se Android non verificato | Conflitto semantics |
| **M101-12** | Chiusura matrice | `MATRIX-M101-results.md` + rubric | Esiti PASS/PARTIAL/BLOCKED | PLANNED / NOT RUN | Completo | Aree PARTIAL documentate | Evidenze mancanti |

---

## 8. Acceptance criteria **CA-T101-01 … CA-T101-10**

| ID | Criterio |
|----|----------|
| **CA-T101-01** | **Nessun** segreto (API key, service_role, connection string, JWT sample completo) in repo tracciato, evidence o log d’esempio non redatti. |
| **CA-T101-02** | **RLS owner-scoped** per dati inventario/prezzi dove il modello dati prevede tenant/owner — o deviazione documentata come rischio accettato/non accettato. |
| **CA-T101-03** | Ruolo **authenticated** con **least privilege**: solo operazioni necessarie; nessun bypass silenzioso in client. |
| **CA-T101-04** | **`service_role` non** impacchettato né richiesto dall’**app** iOS/Android consumer. |
| **CA-T101-05** | Policy **UPDATE/DELETE** (e tombstone) **coerenti** con i flussi sync/cleanup documentati; nessuna sorpresa tipo cleanup test impossibile senza ruolo elevato *senza* che sia stato accettato. |
| **CA-T101-06** | **Live write** ammesso solo con **scope chiaro** (prefisso, ambiente, consenso, collision scan). |
| **CA-T101-07** | **Cleanup** test/sandbox **sicuro** e ripetibile; separazione da dati produzione. |
| **CA-T101-08** | **Evidenze** sempre **redatte** (hash owner/project, niente catalogo reale). |
| **CA-T101-09** | **Android vs iOS** non **divergono** su semantics **owner/auth** per gli stessi endpoint/policy. |
| **CA-T101-10** | **Failure mode** (auth fail, RLS 42501, rete) **non** espongono dati sensibili in UI/log di default. |

---

## 9. Rischi **R101-01 … R101-10**

| ID | Rischio |
|----|---------|
| **R101-01** | RLS **troppo permissiva** (cross-tenant read/write). |
| **R101-02** | RLS **troppo restrittiva** → blocca cleanup/test legit o UX ingestibile. |
| **R101-03** | **Leak service_role** o chiavi in binario, plist commesso, o CI log. |
| **R101-04** | **JWT/config leak** in evidenze o issue tracker. |
| **R101-05** | **Log** con dati reali (barcode, email, importi clienti). |
| **R101-06** | **Owner scoping inconsistente** tra client e policy. |
| **R101-07** | **Cross-platform mismatch** (iOS suppone owner diverso da Android). |
| **R101-08** | **Cleanup test data incompleto** o script pericolosi. |
| **R101-09** | **Policy drift**: migration repo ≠ DB live senza spiegazione. |
| **R101-10** | **Falso claim production-ready** prima dell’audit. |

---

## 10. Go / No-Go per futura EXECUTION

Prima di autorizzare **EXECUTION** (audit attivo o mutazioni):

1. **Consenso utente esplicito** al perimetro (read-only vs write dichiarato per scenario).
2. **Scope Supabase**: default **read-only** per inventory policy; ogni **write** deve essere **dichiarata** (prefisso, tabelle, rollback narrative).
3. **Admin / service_role**: solo per operazioni operative documentate; **mai** nel percorso app consumer; processo di gestione chiavi chiaro.
4. Se si modificano **grants/RLS**: **backup**, **piano rollback**, e task separato se il cambio è ampio.
5. **Zero dati reali** nelle evidenze; solo aggregati o sintetici `TASK*`.
6. **Separazione audit vs remediation**: finding → routing esplicito; nessun “fix” silenzioso fuori scope.

---

## 11. Evidenze previste *(cartella — non creata in questo init)*

**Percorso pianificato:** `docs/TASKS/EVIDENCE/TASK-101/`

| Artefatto | Scopo |
|-----------|--------|
| `MANIFEST.md` | Scope, repo snapshot, ambiente, read/write dichiarato |
| `rls-policy-inventory.md` | Elenco policy per tabella |
| `grants-audit.md` | Ruoli e privilegi |
| `auth-session-audit.md` | Flussi token/sessione client |
| `secrets-scan-notes.md` | Esito grep/scan |
| `logging-privacy-audit.md` | Log e redazione |
| `owner-scope-matrix.md` | Owner per risorsa |
| `live-write-safety-audit.md` | Regole write live |
| `cleanup-retention-policy.md` | Retention e cleanup |
| `android-ios-security-parity.md` | Confronto parity |
| `MATRIX-M101-results.md` | Esiti M101 |
| `PASS-PARTIAL-BLOCKED-rubric.md` | Rubric decisoria |

*(Nessun file creato in questo turno salvo tracking esterno al folder evidence.)*

---

## 12. Stop rules

**BLOCKED** se:

- **Segreti** trovati in repo/evidence non rimovibili nel perimetro consentito.
- **RLS/grants** non ispezionabili (accesso negato anche read-only audit).
- **service_role** richiesto dall’**app** consumer.
- **Owner scoping** ambiguo su tabelle core.
- **Policy live** diversa da **migration** senza spiegazione documentata.
- **Evidenze** non redatte o non pubblicabili.

**PARTIAL** se:

- Audit **statico** ok ma **runtime** non eseguito.
- **Supabase live** non accessibile in lettura.
- **Parity Android** non verificata (solo iOS).

---

## 13. Handoff

| Campo | Valore |
|-------|--------|
| **Prossima fase** | **Planning Review** |
| **Prossimo agente** | **Claude / Reviewer** |
| **Azione consigliata** | Validare coerenza §2–§12, priorità micro-slice, matrice M101, CA-T101, rischi; poi — solo con consenso utente — handoff verso **EXECUTION** con scope read/write esplicito |

**TASK-101** resta **NON DONE** e **NON READY FOR EXECUTION** fino a chiusura Planning Review e consenso esplicito come da §10.

---

## 14. Decisioni *(vuoto in init)*

| # | Decisione | Stato |
|---|-----------|--------|
| — | Nessuna decisione operativa in planning-init | — |

---

## 15. Execution / Review / Fix

*Sezioni riservate a Codex / Reviewer — non compilate in questo init-only.*
