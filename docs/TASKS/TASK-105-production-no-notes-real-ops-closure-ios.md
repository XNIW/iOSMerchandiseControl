# TASK-105 — Production No-Notes / Real Ops Closure iOS

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-105** |
| **Titolo** | **Production No-Notes / Real Ops Closure iOS** |
| **File task** | `docs/TASKS/TASK-105-production-no-notes-real-ops-closure-ios.md` |
| **Stato task** | **ACTIVE** |
| **Fase attuale** | **PLANNING** |
| **Responsabile attuale** | **Claude / Planner** |
| **NON DONE** | **Sì** — il task non è completato; nessun verdict finale di chiusura. |
| **NON READY FOR EXECUTION** | **Sì** — non esiste ancora handoff valido verso EXECUTION; questa revisione è solo planning. |
| **Data creazione** | 2026-05-12 |
| **Ultimo aggiornamento** | 2026-05-12 |
| **Ultimo agente** | **Claude / Planner** |

**Posizione rispetto a TASK-104**

- **TASK-104** resta **DONE** con chiusura **REVIEW PASS FINAL / PASS_WITH_NOTES**, verdict limitato a **realistic shop acceptance sintetica** privacy-safe; **non** si riapre TASK-104 per chiudere le note residue.
- **TASK-105** affronta la **chiusura operativa reale** e le **note residue post TASK-104** in un perimetro nuovo, senza retro-modificare il contratto di accettazione di TASK-104.

---

## 2. Obiettivo

Chiudere le **note residue post TASK-104** senza riaprire TASK-104, costruendo un perimetro documentato e verificabile (in **futura** execution + review + conferma utente) in cui sia **eventualmente lecito proporre** un claim **production no-notes** — **mai** come esito di questo documento di planning.

Il planning stabilisce **solo** micro-slice, criteri, evidenze pianificate, stop conditions e gate; **non** produce esiti di test, **non** usa dati reali, **non** dichiara production-ready globale né production no-notes.

---

## 3. Scope (IN)

- **Excel reali** small/large del negozio con **consenso esplicito** tracciabile e **redazione** nelle evidenze.
- **Backup / rollback** dati reali concordati **prima** di mutazioni significative; responsabilità e ripristino documentati.
- **Accettazione operatore finale** con script/procedura ripetibile e firma implicita (checklist firmata dall’operatore o equivalente tracciabile senza PII in chiaro).
- **Scanner hardware / camera reale** su iPhone; distinzione tra esito hardware PASS e fallback manuale **solo se** accettato formalmente dall’operatore/owner.
- **File provider reale:** Files / iCloud / Share Sheet / locale — scenari effettivamente usati in negozio.
- **Export / share reale** verso la **destinazione effettivamente usata** in negozio (app/posta/cloud cartella concordata), senza path personali non redatti nelle evidenze.
- **Cleanup scoped** o **decisione finale di retention** per dati sintetici prefissati **`TASK104_PASS2_20260512_214804_`** (o equivalente documentato in tracking TASK-104), senza cleanup distruttivo non concordato su dati reali.
- **Nota Android broad unit ByteBuddy/attach:** risoluzione tecnica **oppure** classificazione formale accettata (rischio noto / limite accettato con owner) — senza confonderla con verdict iOS.
- **Privacy scan finale** su artefatti, repo-adiacenza ed evidenze prima di qualsiasi claim no-notes.
- **Criteri espliciti** per un **eventuale** claim production no-notes (solo post execution + review + conferma utente).
- **Conferma esplicita** che TASK-104 resta chiuso e **non** viene riaperto.

---

## 4. Anti-scope (planning e intero task fino a execution autorizzata)

- **Nessuna execution in planning** — nessun passo operativo reale, nessun comando di collaudo eseguito come risultato di questo documento.
- **Nessun Swift / Kotlin / SQL** mutativo nel perimetro di questo turno di planning.
- **Nessuna build / test / runtime** come obbligo o risultato del planning.
- **Nessuna write Supabase** da questo planning.
- **Nessun dato reale usato** nella redazione del planning (solo placeholder e principi).
- **Nessun production-ready globale** dichiarato dal planning.
- **Nessun production no-notes** dichiarato dal planning.

---

## 5. Dipendenze e confini

| Relazione | Dettaglio |
|-----------|-----------|
| **Dipende da** | TASK-104 **DONE** (PASS_WITH_NOTES, perimetro sintetico); TASK-103 **DONE** perimetro P0 controllato — **non** riaperti. |
| **Non riapre** | TASK-104, TASK-103. |
| **Sblocca (potenziale)** | Decisione documentata su claim production no-notes **solo** dopo ciclo execution → review → conferma utente su questo task. |

---

## 6. Micro-slice consigliate

| ID | Nome | Scopo sintetico |
|----|------|-----------------|
| **S105-A** | Preflight post TASK-104 | Inventario note residue, prerequisiti device/account, allineamento versioning build senza eseguire runtime. |
| **S105-B** | Real data consent / backup / rollback | Documento consenso, piano backup, procedure rollback e owner decision. |
| **S105-C** | Real Excel small import | Import file reale piccolo con metriche redatte. |
| **S105-D** | Real Excel large import | Import file reale grande con soglie e osservazioni performance UX redatte. |
| **S105-E** | Operator acceptance script | Checklist operatore, criteri PASS/PARTIAL/BLOCKED operativi. |
| **S105-F** | Scanner hardware camera real test | Verifica camera reale o fallback accettato con evidenza. |
| **S105-G** | File provider / Share Sheet real test | Files / iCloud / locale / ingresso da share. |
| **S105-H** | Export/share real destination validation | Destinazione negozio reale, integrità file, redazione evidenze. |
| **S105-I** | TASK104_PASS2 cleanup or retention final decision | Decisione scoped cleanup vs retention documentata e tracciata. |
| **S105-J** | Android broad unit ByteBuddy/attach resolution or accepted note | Fix, workaround documentato, o nota formale accettata dal owner. |
| **S105-K** | Privacy/security final sweep | Scan finale pre-claim: repo, evidenze, allegati, path. |
| **S105-L** | Production no-notes claim gate | Lista condizioni tutte soddisfatte prima di proporre il claim. |
| **S105-M** | Evidence pack + final planning review | Chiusura evidence + passaggio a review post-execution (futuro). |

---

## 7. Criteri di accettazione (contratto — verifica in futura execution/review)

Execution e review lavoreranno contro questi criteri. Il planning **non** li marca soddisfatti.

- [ ] **CA-105-01 — Consenso dati reali:** consenso esplicito tracciabile per uso Excel/dati negozio nel collaudo; evidenza in pack senza contenuto sensibile in chiaro.
- [ ] **CA-105-02 — Backup pre-mutazione:** backup o export recuperabile documentato **prima** di mutazioni reali; ruolo ripristino definito.
- [ ] **CA-105-03 — Rollback verificabile:** procedura rollback testata almeno a livello documentato (dry-run o ripristino controllato) e registrata redatta.
- [ ] **CA-105-04 — Excel reale small:** import completato su iPhone reale con manifest redatto (dimensioni approssimative, righe, esito).
- [ ] **CA-105-05 — Excel reale large:** import completato con soglia dimensionale concordata e osservazioni UX/tempo redatte.
- [ ] **CA-105-06 — Scanner hardware o fallback accettato:** esito **SCANNER_HARDWARE_PASS** **oppure** **FALLBACK_MANUAL_ACCEPTED** con decisione owner/operatore documentata (non mascherare problemi permessi/camera).
- [ ] **CA-105-07 — File provider reale:** almeno uno scenario tra Files / iCloud / locale / Share Sheet validato in condizioni negozio reale, con recovery documentato se fallisce.
- [ ] **CA-105-08 — Export/share destinazione reale:** export raggiunge la destinazione effettiva usata in negozio; integrità verificata senza path personali in chiaro nelle evidenze.
- [ ] **CA-105-09 — Accettazione operatore finale:** script/checklist operatore completata; esito operativo registrato (PASS / PASS_WITH_NOTES / PARTIAL / BLOCKED) con motivazione.
- [ ] **CA-105-10 — TASK104_PASS2 cleanup/retention:** decisione finale **cleanup scoped** **oppure** **retention** con motivazione e tracciamento; nessuna cancellazione distruttiva non concordata su dati reali.
- [ ] **CA-105-11 — Nota Android ByteBuddy/attach:** risolta (fix/workaround) **oppure** classificata formalmente come limite accettato con owner — separata dal verdict iOS.
- [ ] **CA-105-12 — Privacy scan finale:** sweep completato; nessun dato reale non redatto in repo/evidenze; checklist privacy firmata nel pack.
- [ ] **CA-105-13 — Gate production no-notes:** tutte le condizioni in §10 soddisfatte **prima** di proporre verbalmente o per iscritto il claim no-notes.
- [ ] **CA-105-14 — Tracking coerente:** MASTER-PLAN e file TASK aggiornati post-review come da workflow; TASK-104 citato come chiuso senza riapertura.
- [ ] **CA-105-15 — Nessun claim anticipato:** nessuna dichiarazione production-ready globale o production no-notes prima di execution + review APPROVED + conferma utente.

*(Criteri aggiuntivi possono essere aggiunti in PLANNING prima dell’handoff verso EXECUTION senza rimuovere CA-105-01…15.)*

---

## 8. Evidence pack pianificato (struttura vuota — nessun risultato in PLANNING)

**Directory:** `docs/TASKS/EVIDENCE/TASK-105/`

File pianificati (da creare/popolare solo in execution/review, non obbligatoriamente tutti nello stesso commit):

| File | Contenuto previsto |
|------|-------------------|
| `00-summary.md` | Sintesi run, build/commit redatti, esito macro, link alle altre schede. |
| `01-consent-backup-rollback.md` | Consenso, backup, rollback, owner — solo redatto. |
| `02-real-excel-small-large.md` | Manifest small/large, metriche, esiti import. |
| `03-operator-acceptance.md` | Checklist operatore, firma implicita tracciabile. |
| `04-scanner-hardware.md` | Esito camera reale o fallback accettato. |
| `05-file-provider-share.md` | Scenari Files/iCloud/locale/share. |
| `06-export-real-destination.md` | Destinazione negozio, verifica integrità. |
| `07-task104-pass2-cleanup-retention.md` | Decisione finale TASK104_PASS2 / prefissi sintetici. |
| `08-android-bytebuddy-note.md` | Risoluzione o nota formale Android. |
| `09-privacy-final-scan.md` | Esito sweep privacy/security. |
| `10-production-no-notes-gate.md` | Checklist gate soddisfatta / non soddisfatta. |
| `11-final-verdict.md` | Verdict review post-execution (futuro). |

---

## 9. Stop conditions (interrompere o non proporre claim)

- **Consenso assente** o non documentabile in modo privacy-safe.
- **Backup mancante** o ripristino non chiaro.
- **Dati reali non redatti** nelle evidenze o rischio di leaking in repo.
- **Scanner hardware non verificabile** e **fallback non accettato** formalmente.
- **File provider / share reale non verificabile** nelle condizioni negozio concordate.
- **Operatore non disponibile** per accettazione finale.
- **Cleanup / retention non decidibile** senza rischio operativo — richiede nuova decisione owner o task separato.
- **Privacy scan fallisce** — nessun proseguimento verso claim no-notes.
- **Claim no-notes tentato senza evidence completa** — invalido per policy; tornare a execution/evidence.

---

## 10. Criteri per eventuale claim production no-notes (solo post-ciclo completo)

Condizioni **tutte** necessarie (lista di gate — non attivate dal solo planning):

1. CA-105-01…CA-105-15 (o superset approvato) soddisfatti in review con evidenze incrociate.
2. Nessun problema critico aperto su perdita dati, sync silenziosa catastrofica, o privacy.
3. TASK-104 rimane **chiuso**; eventuali gap sono coperti da TASK-105 senza riapertura retroattiva.
4. Conferma utente esplicita dopo review **APPROVED**.
5. Dichiarazione **production no-notes** limitata al **perimetro documentato** nel verdict (non globale implicito).

---

## 11. Definition of Done (task TASK-105)

**TASK-105 potrà essere DONE solo dopo futura execution + review (loop FIX se necessario) + conferma utente** — **non** durante né al termine del solo planning.

---

## 12. Informazioni generali (template tracking)

- **Dipende da:** TASK-104 (DONE, PASS_WITH_NOTES sintetico); vedi §5.
- **Sblocca:** eventuale dichiarazione formalizzata production no-notes **solo** se §10 e workflow completati.

## Scopo (sintesi)

Portare il sistema da «accettazione negozio sintetica con note» (TASK-104) a una **chiusura operativa reale** con **evidenze redatte**, **sicurezza dati** e **gate** per un claim **no-notes** eventualmente proponibile — senza riaprire TASK-104.

## Contesto

TASK-104 ha lasciato note e limiti tipici di dati sintetici e perimetro controllato; TASK-105 pianifica il lavoro **reale** e la **risoluzione/classificazione** delle note residue in ambito operativo negozio iOS (con riferimenti Android/Supabase solo dove necessario al gate).

## Non incluso (oltre §4)

- Refactor massivi non motivati da blocker documentati in execution.
- Nuove feature prodotto fuori dal perimetro «real ops closure».
- Modifiche schema Supabase salvo task separato approvato.

## File potenzialmente coinvolti (solo riferimento — nessuna modifica in PLANNING)

- Documentazione task ed evidenze: `docs/TASKS/TASK-105*.md`, `docs/TASKS/EVIDENCE/TASK-105/*`.
- Codice iOS/Android/Supabase: **solo** elenco predittivo per execution futura — **nessuna modifica** in questo turno.

---

## Planning (Claude) — completo per validità handoff futuro

### Obiettivo (planning)

Definire micro-slice, criteri, pack evidenze, stop conditions e gate no-notes in modo che una futura EXECUTION possa procedere senza ambiguità e senza riaprire TASK-104.

### Analisi

- TASK-104 ha validato un perimetro **sintetico** con **PASS_WITH_NOTES**; le note residue richiedono **dati reali con consenso**, **hardware reale**, **provider/share reali** e **decisioni di retention/cleanup** su prefissi sintetici TASK-104.
- Il rischio principale è **perdita dati / privacy leak / claim anticipati**; mitigazione = backup, redazione, stop conditions e gate §10.
- La nota **Android ByteBuddy/attach** è **trasversale** ma non deve bloccare il verdict iOS se formalmente classificata e accettata.

### Approccio proposto

1. Completare planning (questo documento) e ottenere **handoff esplicito** verso EXECUTION quando il progetto sarà **READY FOR EXECUTION** (non ora).
2. Eseguire micro-slice **S105-A … S105-M** in ordine dipendente (es. B prima di C/D; K prima di L).
3. Consolidare evidence pack sotto `docs/TASKS/EVIDENCE/TASK-105/`.
4. Review Claude su completezza evidenze vs CA; loop FIX se necessario.
5. Solo dopo conferma utente: eventualmente formulare claim **production no-notes** nel perimetro §10.

### File coinvolti (planning)

- Questo file: `docs/TASKS/TASK-105-production-no-notes-real-ops-closure-ios.md`.
- Directory evidenze pianificata: `docs/TASKS/EVIDENCE/TASK-105/` (file elencati in §8).

### Rischi identificati

| Rischio | Mitigazione pianificata |
|---------|-------------------------|
| Leak dati reali in git/evidenze | Redazione obbligatoria; privacy scan K; stop condition |
| Assenza backup | Stop condition; CA-105-02 |
| Operatore assente | Stop condition; pianificare finestra |
| Scanner non disponibile | Fallback solo con accettazione formale |
| Scope creep verso fix codice | Anti-scope §4; task separato per patch |
| Claim no-notes prematuro | CA-105-13/15; §10 |

### Handoff → Execution

> **NOTA:** Il task è esplicitamente **NON READY FOR EXECUTION** alla pubblicazione di questo planning. La sezione seguente definisce il **handoff atteso** solo dopo aggiornamento di stato/fase da parte del planner quando i prerequisiti saranno soddisfatti.

- **Prossima fase (quando READY):** EXECUTION  
- **Prossimo agente:** CODEX  
- **Azione consigliata (futura):** Avviare da **S105-A**, creare file evidenza vuoti popolandoli incrementalmente; rispettare stop conditions; non proporre claim no-notes fino a **S105-L** completo.  
- **Fino ad allora:** nessuna execution; nessun dato reale; nessun claim production-ready globale o production no-notes.

---

## Execution (Codex)

*(Vuoto — da compilare solo in fase EXECUTION.)*

## Fix (Codex)

*(Vuoto.)*

## Review (Claude)

*(Vuoto — da compilare post-execution.)*

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Non riaprire TASK-104 per note residue | Riapertura TASK-104 | Coerenza contratto chiusura TASK-104 | attiva |
| 2 | Claim no-notes solo dopo gate §10 | Claim implicito da sintetico | Riduce rischio legale/operativo | attiva |

---

## Checklist conferma fine creazione file (planning only)

- [x] **TASK-105** risulta **ACTIVE / PLANNING** nel contenuto di questo file.
- [x] **TASK-105 NON DONE** — dichiarato esplicitamente.
- [x] **TASK-105 NON READY FOR EXECUTION** — dichiarato esplicitamente.
- [x] **TASK-104 non riaperto** — confini documentati in §1 e CA-105-14.
- [x] **Nessuna execution** descritta come eseguita in questo planning.
- [x] **Nessun dato reale** nel testo del planning.
- [x] **Nessun claim production-ready globale** né **production no-notes** come esito del planning.
