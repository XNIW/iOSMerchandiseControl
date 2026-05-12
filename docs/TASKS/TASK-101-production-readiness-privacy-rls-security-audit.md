# TASK-101 — Production readiness privacy / RLS / security audit

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-101** |
| **Titolo** | **Production readiness privacy / RLS / security audit** |
| **File task** | `docs/TASKS/TASK-101-production-readiness-privacy-rls-security-audit.md` |
| **Stato task** | **DONE** |
| **Fase attuale** | **Chiusura — REVIEW PASS FINAL** |
| **Responsabile attuale** | **Utente / Chiusura** |
| **Data creazione** | 2026-05-10 |
| **Ultimo aggiornamento** | 2026-05-12 12:50 -0400 — **Review finale Codex completata per override utente / TASK-101 DONE** |

**TASK-101 DONE / REVIEW PASS FINAL.**

**EXECUTION ESEGUITA PER OVERRIDE ESPLICITO UTENTE** — il file era ancora in planning-init; l'utente ha autorizzato direttamente audit statico/runtime, lettura live Supabase e remediation completa. Deviazione registrata in §15.

**Handoff turno corrente:** **DONE / Nessun handoff tecnico bloccante**

**Flag:** **`TASK-101_DONE_REVIEW_PASS_FINAL_USER_OVERRIDE`** — execution e review/fix completate da Codex con evidenze, remediation iOS/backend/Android mirate, build/test/lint PASS; **TASK-101 DONE**; **nessuna** apertura **TASK-102**; **nessun** claim production-ready globale 100%.

> **Nota di riconciliazione 2026-05-12 12:50 -0400:** le sezioni §3-§14 restano contesto storico del planning-init. Lo stato operativo reale post-override è documentato in §15 e nell'evidence pack `docs/TASKS/EVIDENCE/TASK-101/`.

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

**[STORICO PLANNING — SUPERATO DAL §15]** In questa fase iniziale, **TASK-101** restava **NON DONE** e **NON READY FOR EXECUTION** fino a chiusura Planning Review e consenso esplicito come da §10.

---

## 14. Decisioni *(vuoto in init)*

| # | Decisione | Stato |
|---|-----------|--------|
| — | Nessuna decisione operativa in planning-init | — |

---

## 15. Execution / Review / Fix

### Execution (Codex) — 2026-05-10 23:10 -0400

> **Storico:** sezione superata dalla review finale 2026-05-12, che ha chiuso i finding residui e portato TASK-101 a DONE.

#### Override operativo

- Il task file e il MASTER-PLAN indicavano ancora **PLANNING / NON READY FOR EXECUTION**.
- L'utente ha fornito override esplicito per procedere con TASK-101 in modalità **EXECUTION end-to-end**, includendo audit statico/runtime, query Supabase live, remediation e test.
- Impatto processo: execution avviata senza handoff formale Claude -> Codex nel file task; deviazione documentata qui e nelle evidenze. Transizione finale applicata: **EXECUTION -> REVIEW**, senza marcare DONE.

#### Obiettivo compreso

Portare TASK-101 a una execution verificabile per audit privacy/RLS/security/readiness: inventario RLS/grants, scan privacy/segreti/log, owner scoping, auth/session, parity Android, finding routing, remediation ragionevoli e handoff finale review.

#### File controllati

- Tracking: `docs/MASTER-PLAN.md`, questo file task.
- iOS core: `SupabaseConfig.swift`, `SupabaseClientProvider.swift`, `SupabaseAuthService.swift`, `SupabaseAuthViewModel.swift`, `SupabaseInventoryService.swift`, `SupabaseManualPushService.swift`, `SyncEventOutboxState.swift`, `OptionsView.swift`.
- iOS logging/UI: `ContentView.swift`, `DatabaseView.swift`, `GeneratedView.swift`, `HistoryEntry.swift`, `HistoryView.swift`, `EditProductView.swift`.
- iOS tests: `SupabaseConfigSecurityTests.swift`, `SyncEventOutboxStateTests.swift`, `SupabaseSyncEventDebugViewModelTests.swift`, `SupabaseManualPushServiceTests.swift`.
- Supabase: local migrations in `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/` and live metadata for RLS/grants/functions/migration list.
- Android reference: auth/config/catalog/price/sync-event/session remote sources and local migration hardening file.

#### Piano minimo eseguito

1. Snapshot e manifest.
2. Traceability seed S101 -> CA-T101 -> M101 -> evidence -> risk -> decision.
3. Static scan iOS, evidence e Android reference.
4. iOS local privacy/logging/auth audit.
5. Supabase schema/RLS/grants/function inventory live.
6. Threat model e data-flow.
7. UX/privacy/accessibility audit statico.
8. Runtime mirato con query live Supabase, lint schema, build/test Xcode.
9. Findings routing con remediation diretta dove piccola e verificabile.
10. Decisione finale PASS/PARTIAL/BLOCKED e handoff review.

#### Modifiche fatte

- iOS privacy sanitizer rafforzato: redazione email, URL HTTP(S), UUID e identificativi numerici lunghi.
- `SupabaseInventoryServiceError.safeDiagnosticDetail` ora usa sanitizer condiviso.
- Query iOS read/preview/read-back/update su inventario/prezzi rafforzate con filtro esplicito `owner_user_id == session.user.id` oltre a RLS.
- Log iOS potenzialmente rumorosi o contestuali resi DEBUG-only/generici.
- UI account Supabase iOS maschera email e owner UUID.
- Test aggiunti/estesi per redazione diagnostica, sanitizer e display account privacy-safe.
- Supabase live: revocato EXECUTE a `PUBLIC`, `anon`, `authenticated` su `public.rls_auto_enable()`, funzione SECURITY DEFINER usata da event trigger; verifica post-fix PASS.
- Supabase locale: aggiunta migration no-op-safe `20260511030000_task101_revoke_rls_auto_enable_public_execute.sql` nel workspace backend.
- Evidence pack TASK-101 creato in `docs/TASKS/EVIDENCE/TASK-101/`.

#### Evidenze prodotte

- `docs/TASKS/EVIDENCE/TASK-101/MANIFEST.md`
- `docs/TASKS/EVIDENCE/TASK-101/TRACEABILITY-S101-CA-M101.md`
- `docs/TASKS/EVIDENCE/TASK-101/MATRIX-M101-results.md`
- `docs/TASKS/EVIDENCE/TASK-101/findings-register.md`
- `docs/TASKS/EVIDENCE/TASK-101/data-flow-map.md`
- `docs/TASKS/EVIDENCE/TASK-101/threat-model.md`
- `docs/TASKS/EVIDENCE/TASK-101/ios-local-privacy-audit.md`
- `docs/TASKS/EVIDENCE/TASK-101/rls-policy-inventory.md`
- `docs/TASKS/EVIDENCE/TASK-101/grants-audit.md`
- `docs/TASKS/EVIDENCE/TASK-101/auth-session-audit.md`
- `docs/TASKS/EVIDENCE/TASK-101/secrets-scan-notes.md`
- `docs/TASKS/EVIDENCE/TASK-101/logging-privacy-audit.md`
- `docs/TASKS/EVIDENCE/TASK-101/owner-scope-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-101/live-write-safety-audit.md`
- `docs/TASKS/EVIDENCE/TASK-101/cleanup-retention-policy.md`
- `docs/TASKS/EVIDENCE/TASK-101/android-ios-security-parity.md`
- `docs/TASKS/EVIDENCE/TASK-101/ux-privacy-accessibility-notes.md`
- `docs/TASKS/EVIDENCE/TASK-101/test-build-runtime-report.md`
- `docs/TASKS/EVIDENCE/TASK-101/PASS-PARTIAL-BLOCKED-rubric.md`
- `docs/TASKS/EVIDENCE/TASK-101/decision-final.md`

#### Check eseguiti

- ✅ ESEGUITO — **Build compila**: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` PASS.
- ✅ ESEGUITO — **Nessun warning nuovo introdotto**: warning Swift introdotto inizialmente su `requireAuthenticatedSession()` corretto e build rerun PASS; resta solo warning AppIntents metadata toolchain/preesistente.
- ✅ ESEGUITO — **Test mirati**: `SupabaseConfigSecurityTests`, `SyncEventOutboxStateTests`, `SupabaseSyncEventDebugViewModelTests`, `SupabaseManualPushServiceTests` PASS; xcresult `Test-iOSMerchandiseControl-2026.05.10_23-01-18--0400.xcresult`.
- ✅ ESEGUITO — **Supabase live RLS/grants/function inventory**: query metadata PASS; remediation `rls_auto_enable()` verificata.
- ✅ ESEGUITO — **Supabase schema lint execution**: `supabase db lint --linked --level warning` registrato PASS nella execution iniziale / no schema errors found.
- ⚠️ NON ESEGUIBILE — **Supabase schema lint review rerun storico**: in review 2026-05-11 `supabase db lint --linked --level warning` non era autenticabile verso Postgres linked senza credenziale DB valida; superato dal rerun finale 2026-05-12 PASS.
- ✅ ESEGUITO — **Migration drift audit**: `supabase migration list --linked` eseguito, esito PARTIAL per drift documentato.
- ✅ ESEGUITO — **Secret/evidence scan**: TASK-101 evidence scan senza email/token/connection string; solo termini policy nel codice/evidence.
- ✅ ESEGUITO — **git diff whitespace**: `git diff --check` PASS.
- ⚠️ NON ESEGUIBILE — **Supabase local Docker/status/dump**: Docker daemon non disponibile, quindi `supabase status`/dump locale non completabili.
- ⚠️ NON ESEGUIBILE — **Simulator manuale completo / OAuth UI**: non ripetuto in questa execution; copertura tramite static audit, runtime metadata Supabase e XCTest/build.
- ⚠️ NON ESEGUIBILE — **Android build/test runtime**: Android usato come riferimento statico; nessuna patch Android e nessun build/test Android nel perimetro effettivo.
- ✅ ESEGUITO — **Criteri di accettazione verificati**: CA-T101-01..10 mappati in traceability/matrix; esito globale PARTIAL documentato.

#### Findings principali

- **F101-01 HIGH CLOSED**: `rls_auto_enable()` SECURITY DEFINER era eseguibile da ruoli client; revoca applicata e verificata.
- **F101-02 MEDIUM OPEN**: drift locale/remoto migrations Supabase.
- **F101-03 MEDIUM OPEN**: leaked password protection Supabase Auth da abilitare via dashboard.
- **F101-04 LOW OPEN**: grants legacy ampi ma RLS fail-closed.
- **F101-05 LOW OPEN**: Android reference logga raw `userId`.
- **F101-06 LOW CLOSED**: iOS mostrava owner/email completi in UI account; mascherato.
- **F101-07 NOTE CLOSED**: redazione diagnostica iOS rafforzata.
- **F101-08 NOTE OPEN**: assente `PrivacyInfo.xcprivacy`, da validare prima di release App Store.
- **F101-09 MEDIUM CLOSED**: `client_event_id` da plan fingerprint poteva persistere owner UUID/barcode/nome prodotto; ora usa hash SHA-256 e test regressivo.
- **F101-10 LOW CLOSED**: collision scan DEBUG TASK-045 ora aggiunge owner filter esplicito oltre a RLS.

#### Rischi rimasti

- Migrazione Supabase locale/remota non allineata: non applicare `migration up` automatico senza review dedicata.
- Retention/cleanup test data documentata ma non automatizzata.
- Full manual OAuth/simulator/accessibility pass non eseguito in TASK-101.
- Android privacy log raw userId resta fuori dalla patch iOS.
- TASK-101 non deve essere considerato DONE o production-ready globale 100%.

#### Decisione finale

**TASK-101 Execution result: PARTIAL / READY FOR REVIEW.**

PASS per iOS client privacy/security, RLS owner model, service_role in consumer app, logging redaction, evidence redaction, build/test mirati. PARTIAL per grants/migration drift, retention automation, Android parity runtime/log, full manual simulator/OAuth/accessibility.

#### Handoff post-execution verso Claude

| Campo | Valore |
|-------|--------|
| **Prossima fase** | **REVIEW** |
| **Prossimo agente** | **Claude / Reviewer** |
| **Stato task** | **ACTIVE / REVIEW** |
| **Esito proposto** | **PARTIAL / READY FOR REVIEW** |
| **TASK-102** | Non aperto |
| **Azione richiesta** | Review del diff iOS, migration Supabase locale, DDL live applicata, evidence pack e finding aperti; decidere se accettare PARTIAL o richiedere FIX. |

### Review/Fix (Codex) — 2026-05-11 00:03 -0400

> **Storico:** sezione superata dalla review finale 2026-05-12, che ha rieseguito Supabase local/linked, Android e iOS 26.5.

#### Obiettivo compreso

Eseguire review professionale della execution TASK-101 senza fidarsi del report precedente, correggendo direttamente problemi reali e riallineando evidence/tracking senza trasformare PARTIAL in DONE se i check Supabase/release restano incompleti.

#### File controllati

- Tracking/evidence: `docs/MASTER-PLAN.md`, questo file task, tutti i file in `docs/TASKS/EVIDENCE/TASK-101/`.
- iOS review/fix: `SupabaseInventoryService.swift`, `SupabaseManualPushService.swift`, `SyncEventOutboxEnqueueService.swift`, `SyncEventOutboxState.swift`, UI account/logging files modificati dalla execution.
- Test review/fix: `SyncEventOutboxEnqueueServiceTests.swift`, `SyncEventOutboxStateTests.swift`, più suite TASK-101 mirata e full XCTest.
- Supabase backend: migration locale `20260511030000_task101_revoke_rls_auto_enable_public_execute.sql`, `supabase migration list --linked`, lint linked/local dove possibile.

#### Piano minimo

1. Leggere task, MASTER, diff reale ed evidence pack.
2. Verificare owner scoping, redazione, log, outbox/manual push, migration Supabase e coerenza evidence.
3. Applicare solo fix moderni e tracciabili per problemi confermati.
4. Rerun build/test/check rilevanti.
5. Aggiornare evidence/tracking con esiti reali e rischi residui.

#### Bug/problemi trovati

- `client_event_id` derivato da `planFingerprint` manual push poteva persistere nel local outbox / remote sync event dati grezzi come owner UUID, barcode o nome prodotto.
- Collision scan DEBUG TASK-045 usava RLS ma non aggiungeva filtro owner esplicito client-side.
- Create manual push accettava payload con owner impostato dal chiamante senza validazione locale esplicita contro la sessione autenticata.
- Evidence precedente dichiarava linked schema lint PASS senza distinguere che in review il rerun non è stato riproducibile per credenziali DB linked assenti/non valide.
- Sezioni planning-only §3-§14 erano ancora leggibili come stato operativo corrente; ora sono marcate come contesto storico.

#### Fix applicati

- `SyncEventOutboxEnqueueService`: fingerprint non vuoti hashati con SHA-256 prima di costruire `client_event_id`.
- `SupabaseInventoryService`: TASK-045 supplier/category/product collision scan ora passa `session.user.id` e filtra `owner_user_id`.
- `SupabaseManualPushService`: create payload supplier/category/product validati contro owner della sessione prima dell'insert; update/read-back/read-many restano owner-scoped.
- Test aggiunti/estesi per `client_event_id` hashato e sanitizer multi-shape.
- Evidence aggiornata con F101-09/F101-10, stato lint linked review, full XCTest e scansione redazione.

#### Check eseguiti

- ✅ ESEGUITO — **Build compila**: Release simulator iPhone 17 Pro iOS 26.4.1 PASS.
- ✅ ESEGUITO — **Nessun warning nuovo introdotto**: Release build PASS; resta solo warning AppIntents metadata toolchain/preesistente.
- ✅ ESEGUITO — **Test mirati review**: `SyncEventOutboxEnqueueServiceTests` + `SyncEventOutboxStateTests` PASS.
- ✅ ESEGUITO — **Suite TASK-101 mirata**: config/security, debug view model, manual push, outbox state/enqueue PASS.
- ✅ ESEGUITO — **Full XCTest**: final review rerun PASS, 640 passed, 12 skipped, 0 failed.
- ✅ ESEGUITO — **git diff whitespace**: `git diff --check` PASS.
- ✅ ESEGUITO — **Evidence/task privacy scan**: nessun match per email/JWT/bearer/API key/connection string/raw Supabase REST URL; UUID/long-number scan solo timestamp migration.
- ✅ ESEGUITO — **Supabase migration list linked**: eseguito, drift confermato e documentato.
- ⚠️ NON ESEGUIBILE — **Supabase local Docker/start/status/lint**: Docker command/daemon non disponibile.
- ⚠️ NON ESEGUIBILE — **Supabase linked lint review rerun storico**: autenticazione Postgres linked fallita nel pass 2026-05-11; superato dal rerun finale 2026-05-12 PASS.
- ⚠️ NON ESEGUIBILE — **Simulator manuale UI/OAuth/accessibility completo**: non ripetuto in review; copertura statica + XCTest/build.
- ⚠️ NON ESEGUIBILE — **Android runtime/build**: Android resta riferimento statico, finding F101-05 aperto.

#### Rischi rimasti

- Drift migration Supabase locale/remoto ancora aperto.
- Leaked password protection da abilitare in Supabase dashboard.
- Grants legacy ampi restano LOW follow-up con RLS fail-closed.
- Android raw `userId` log resta aperto fuori patch iOS.
- Assenza `PrivacyInfo.xcprivacy` da validare prima di distribuzione App Store.
- Retention/cleanup policy documentata ma non automatizzata.

#### Handoff post-review/fix verso reviewer

| Campo | Valore |
|-------|--------|
| **Prossima fase** | **REVIEW** |
| **Prossimo agente** | **Claude / Reviewer o utente** |
| **Stato task** | **ACTIVE / REVIEW** |
| **Esito review Codex** | **PARTIAL / READY FOR REVIEW** |
| **Motivo non-DONE** | Supabase drift, linked/local lint non completamente riproducibili in review, leaked-password protection dashboard, Android/release readiness residui. |
| **Azione richiesta** | Accettare PARTIAL come follow-up routing o aprire FIX mirato per backend/Android/release-readiness. |

### Review finale / Chiusura (Codex) — 2026-05-12 12:50 -0400

#### Override operativo

- L'utente ha richiesto esplicitamente di portare TASK-101 a DONE reale se i criteri fossero verificabili, superando la regola standard del workflow che impedisce a Codex di marcare DONE.
- L'override è stato applicato solo dopo rerun di iOS, Android, Supabase local/linked, privacy manifest, evidence scan e riconciliazione finding.

#### Fix applicati

- iOS: aggiunto `iOSMerchandiseControl/PrivacyInfo.xcprivacy` con UserDefaults required-reason API `CA92.1`, nessun tracking e nessuna data collection dichiarata.
- Android: rimosso raw `userId` dal log runtime `Auth: sessione attiva` in `MerchandiseControlApplication.kt`.
- Evidence: aggiunti output Android, iOS 26.5, Supabase local/linked, introspection drift e privacy manifest; aggiornati matrix, traceability, findings, decisione finale e report test.

#### Check finali

- ✅ ESEGUITO — `git diff --check` iOS PASS.
- ✅ ESEGUITO — `git diff --check` Android PASS.
- ✅ ESEGUITO — iOS runtime install: `xcodebuild -downloadPlatform iOS -buildVersion 26.5 -architectureVariant arm64` PASS.
- ✅ ESEGUITO — iOS Release build: iPhone 17 Pro iOS 26.5 simulator PASS.
- ✅ ESEGUITO — iOS TASK-101 targeted XCTest: 84 passed, 0 failed.
- ✅ ESEGUITO — iOS full XCTest: 640 passed, 12 skipped, 0 failed.
- ✅ ESEGUITO — iOS simulator launch smoke: install/launch/screenshot PASS.
- ✅ ESEGUITO — iOS privacy manifest: `plutil -lint` PASS; Release simulator bundle contiene il manifest app-level.
- ✅ ESEGUITO — Supabase local: `supabase status` PASS; `supabase db lint --local --level warning` PASS/no schema errors.
- ✅ ESEGUITO — Supabase linked: `supabase migration list --linked` eseguito; `supabase db lint --linked --level warning` PASS/no schema errors.
- ✅ ESEGUITO — Supabase drift: introspezione read-only PASS; oggetti live richiesti presenti; drift classificato registry/history non-blocking.
- ✅ ESEGUITO — Android: `testDebugUnitTest`, `lintDebug`, `assembleDebug`, `assembleRelease` PASS con JBR Android Studio.
- ✅ ESEGUITO — Evidence privacy scan: nessun segreto reale; match residui solo per nomi ruolo/policy o placeholder documentati.
- ⚠️ NON ESEGUIBILE — OAuth manuale con account reale non ripetuto per evitare produzione di evidence sensibili; coperto da static/test/prior evidence e smoke app.

#### Findings finali

- F101-01 CLOSED.
- F101-02 CLOSED_NON_BLOCKING_OPS: drift registry/history documentato, live schema coerente, nessun repair cieco.
- F101-03 CLOSED_NON_BLOCKING_OPS: leaked-password protection è dashboard/Auth setting; client iOS/Android non hanno password login.
- F101-04 CLOSED_NON_BLOCKING_OPS: legacy grants fail-closed sotto RLS, cleanup least-privilege futuro non bloccante.
- F101-05 CLOSED: Android raw `userId` log corretto e verificato.
- F101-06 CLOSED.
- F101-07 CLOSED.
- F101-08 CLOSED: privacy manifest aggiunto e verificato.
- F101-09 CLOSED.
- F101-10 CLOSED.

#### Rischi residui

- Eventuale repair della migration history Supabase va fatto come operazione Ops deliberata, non automatica.
- Leaked-password protection va confermata in Dashboard se in futuro viene abilitato password login.
- Full screen-by-screen accessibility/OAuth manual pass resta normale gate release-candidate, non blocker TASK-101.

#### Decisione finale

**TASK-101 DONE / REVIEW PASS FINAL.**

Non è un claim "production-ready globale 100%"; è chiusura del perimetro TASK-101 con evidence completa, redatta e verificata, senza BLOCKER/HIGH aperti.
