# TASK-104 — Real Shop Acceptance iOS ↔ Supabase ↔ Android

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-104** |
| **Titolo** | **Real Shop Acceptance iOS ↔ Supabase ↔ Android** |
| **File task** | `docs/TASKS/TASK-104-real-shop-acceptance-ios-supabase-android.md` |
| **Stato task** | **DONE** |
| **Fase attuale** | **Chiusura — REVIEW PASS FINAL / PASS_WITH_NOTES** |
| **Responsabile attuale** | **Nessuno / Task chiuso** |
| **Data creazione** | 2026-05-12 |
| **Ultimo aggiornamento** | 2026-05-12 22:35 -0400 — **REVIEW PASS FINAL / PASS_WITH_NOTES**; verdict limitato a realistic shop acceptance sintetica privacy-safe con prefisso `TASK104_PASS2_20260512_214804_`; **non** real user data acceptance, **non** production-ready globale, **non** production no-notes, **non** 100% globale. |
| **Ultimo agente** | **Codex / Reviewer** |

**Planning Review:** **PASS per override esplicito utente** — handoff autorizzato verso **EXECUTION** in questo turno.

**TASK-104 DONE / Chiusura — REVIEW PASS FINAL / PASS_WITH_NOTES.**  
Verdict limitato a **realistic shop acceptance** con dati sintetici privacy-safe; non dichiarare real user data acceptance, production-ready globale, production no-notes o 100% globale.  
**TASK-105** resta **TODO / Planning — non aperto** *(nessun file task TASK-105; nessuna promozione ACTIVE).*  
**TASK-103** resta **DONE / Chiusura — REVIEW PASS FINAL** — verdict **Supabase iOS cross-platform acceptance 100% PASS** **solo** nel perimetro P0 TASK-103; **non** si riapre e **non** si modifica retroattivamente come claim globale.

**Vincoli ancora validi:** nessun Swift/Kotlin/SQL mutativo non necessario, nessuno schema/RLS/grant/migration fuori scope, nessun write Supabase senza gate consenso/backup/owner, nessun dato reale non redatto, nessun risultato inventato, nessuna dichiarazione **100% pratico**, **production-ready**, **production no-notes** o claim globale.

---

## 2. Repository e fonti (read-only in PLANNING)

| Repo | Path | Ruolo |
|------|------|--------|
| **iOS (target principale)** | `/Users/minxiang/Desktop/iOSMerchandiseControl` | Unica codebase da modificare in **futura** EXECUTION, solo se il piano lo richiede. |
| **Android (riferimento funzionale)** | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` | Parità comportamentale e verifica lettura/scrittura; **non** target di patch salvo blocker documentato e scope separato. |
| **Supabase** | `/Users/minxiang/Desktop/MerchandiseControlSupabase` | Schema/migration **solo lettura** in PLANNING; nessuna DDL/migration nel task salvo follow-up esplicito. |

---

## 3. Obiettivo

Validare l’app **in uso reale negozio** su **iPhone reale**, **Android reale** e **Supabase live condiviso**, con **account/sessione reale controllata**, **file Excel reali** dell’utente (piccolo e grande), **dati reali solo con consenso esplicito**, e **evidenze sempre privacy-safe / redatte**.

Obiettivo di business: dopo **execution + review APPROVED + conferma utente** di questo task, sarà **lecito** dichiarare (in tracking separato) che la soluzione è **«usabile nel negozio al 100% pratico»** — **non** è obiettivo di **questo** documento di planning dichiararlo ora.

Obiettivo operativo aggiuntivo: trasformare il collaudo reale in una **procedura ripetibile da negozio**, non in una prova improvvisata. La futura execution deve produrre un percorso chiaro per l’utente: cosa preparare, quali azioni fare su iOS/Android, quali risultati aspettarsi, come riconoscere errori recuperabili e quando fermarsi.

---

## 4. Contesto da TASK-103

- **TASK-103** ha chiuso l’**accettazione cross-platform controllata** su device fisici con dataset **sintetico** prefissato `TASK103_REAL_*`, CA-103-01…18 in **PASS** / **PASS_AFTER_FIX**, verdict **Supabase iOS cross-platform acceptance 100% PASS** nel **solo** perimetro P0 TASK-103 (`docs/TASKS/EVIDENCE/TASK-103/00-summary.md`, `12-final-verdict.md`).
- **Nessun dato reale del negozio** è stato usato come fixture in TASK-103.
- Restano **P1 non bloccanti** documentati in verdict (es. VoiceOver completo, scanner camera reale per acceptance sintetica) — da non confondere con il perimetro **negozio reale** di TASK-104.

---

## 5. Differenza: «P0 controlled acceptance» (TASK-103) vs «real shop acceptance» (TASK-104)

| Aspetto | TASK-103 (P0 controllato) | TASK-104 (negozio reale) |
|--------|---------------------------|---------------------------|
| **Dati** | Sintetici, prefisso run, collision scan, cleanup scoped | **File Excel e dati operativi reali** solo con **consenso** e **backup** |
| **Obiettivo** | Verdict integrazione iOS↔Supabase↔Android su contratto P0 | Validare flussi **quotidiani** del negozio su stack reale |
| **Evidenze** | Privacy-safe per natura (sintetico) | Obbligo **redazione** aggressiva (nessun barcode/PII commerciale in chiaro) |
| **Rischio** | Contenuto da harness/cleanup | **Perdita dati**, duplicati, pending bloccati — richiede disciplina operatore |
| **Claim** | 100% PASS **perimetro TASK-103** | **Non** claim production-ready / no-notes; eventuale «100% pratico» **solo** post-chiusura formalizzata del task |

---

## 6. Perimetro (scope IN)

- **Device:** iPhone fisico; dispositivo Android fisico; stesso progetto Supabase **live** già in uso (non “nuovo” ambiente salvo decisione documentata).
- **Account/sessione:** login reale **controllato** (stesso owner dove applicabile; vedi RLS); sessione valida su entrambi i client prima di round-trip mutativi.
- **Excel reale:** almeno un import **piccolo** e uno **grande** (soglie definite in execution con l’utente; es. righe/ MB documentati **in evidenza redatta**).
- **Flussi iOS (repo-grounded):**
  - **Home / import:** `InventoryHomeView` → `ExcelSessionViewModel` / `ExcelAnalyzer` (`.xlsx` / `.xls` / HTML).
  - **Pre-generazione:** `PreGenerateView` → `generateHistoryEntry`.
  - **Inventario:** `GeneratedView` — modifica righe, completamento, salvataggio.
  - **Cronologia:** `HistoryView` / `HistoryEntry` — persistenza sessione.
  - **Database:** `DatabaseView` — CRUD prodotti, fornitori, categorie, storico prezzi.
  - **ProductPrice:** coerenza **current / previous** vs storico (`ProductPrice` / export dove applicabile).
  - **Scanner:** `BarcodeScannerView` — **camera reale**; fallback **manuale / ricerca** se scanner non accettabile.
  - **Export / condivisione:** export Excel / full DB come già esposto dall’app.
  - **Sync / pending:** `OptionsView` — **Controlla cloud**, review sheet, **pending** / outbox / summary **come da design Release** (`SupabaseManualSyncViewModel` e servizi collegati).
- **Round-trip bidirezionale:** almeno un ciclo **iOS → Supabase → Android** e uno **Android → Supabase → iOS** con **dati reali** (post-consenso), non solo smoke sintetico.
- **Offline/retry:** scenario **breve** documentato (es. disconnessione controllata, retry manuale) senza lasciare stato inconsistente non spiegato.
- **UX reale durante il collaudo:** osservare frizioni, testi ambigui, azioni troppo nascoste, loading non chiari, errori non recuperabili e punti in cui l’utente deve “indovinare” cosa fare. In TASK-104 si possono proporre ritocchi UX **solo come follow-up pianificato**, non implementare patch.
- **Metriche operative:** registrare in forma redatta tempi percepiti, dimensione file, conteggio righe, numero prodotti/prezzi toccati, numero pending/outbox e stato finale. Non serve precisione da benchmark; serve capire se il flusso è sostenibile in negozio.
- **Tracciabilità build/run:** registrare commit/build iOS e Android, versione app, ambiente Supabase redatto, timestamp run, rete usata e operatore. Serve a rendere il verdict ripetibile e a evitare ambiguità tra prove diverse.
- **Decision log:** ogni deviazione dal percorso previsto deve essere registrata con motivo, scelta fatta e impatto su PASS/PARTIAL/BLOCKED.
- **Owner/RLS sanity check:** prima di qualunque round-trip reale, verificare in modo **non distruttivo** che iOS e Android stiano lavorando sullo stesso perimetro owner/project **redatto**; se non è chiaro, **bloccare** la mutazione.
- **Baseline pre/post mutazione:** prima dei round-trip reali, registrare **snapshot redatto** di prodotti sentinella, **current/previous price** e **pending/outbox**; dopo ogni mutazione verificare **solo delta atteso**, evitando controlli massivi su dati reali.
- **No silent overwrite:** qualunque **conflitto**, **stale baseline** o **differenza inattesa** tra locale/remoto deve fermare apply/push automatici e passare a **review manuale**; niente sovrascritture silenziose su dati negozio.
- **Single-writer protocol:** durante un round-trip reale, **un solo client alla volta** deve mutare dati negozio; l’altro client resta in **lettura/verifica** finché la mutazione non è confermata. Evitare modifiche **concorrenti** iOS/Android sulle **stesse sentinelle**.
- **Sequenza temporale esplicita:** ogni mutazione reale deve avere ordine chiaro **pre-read → mutate → sync/push → remote read-back → other-client pull/read → post-check**; se un passaggio **salta**, il verdict diventa almeno **PARTIAL**.
- **Esito scanner differenziato:** distinguere **SCANNER_HARDWARE_PASS** da **FALLBACK_MANUAL_ACCEPTED**; il fallback può permettere chiusura con note, ma **non** deve mascherare un problema camera/permessi.
- **Timebox / pause-resume:** il collaudo reale deve poter essere sospeso senza perdere il filo: registrare ultimo step completato, stato dati, decisione rollback/cleanup pendente e prossima azione sicura.
- **Contingency planning:** per ogni rischio P0 prevedere prima della execution cosa fare: stop, rollback, follow-up, fix lane separata o accettazione con note.
- **File provider reali:** validare selezione da **Files / iCloud / locale / condivisione** dove disponibile; se il provider reale fallisce, registrare **recovery/fallback** senza copiare **path personali** in evidenza.
- **Artefatti temporanei:** file esportati, **cache**, screenshot e log locali usati per il collaudo devono avere **destino chiaro**: eliminati, redatti o conservati **fuori repo** con consenso. **Nessun** allegato reale nel repository.
- **Lingua/copy operativa:** verificare che la **lingua** realmente usata dall’operatore sia **coerente e comprensibile** nelle azioni principali; eventuale **mixed-language** o copy tecnico va tracciato come **UX follow-up**.
- **Evidenze:** solo in `docs/TASKS/EVIDENCE/TASK-104/` secondo §12; **mai** dati reali non redatti.

---

## 7. Fuori perimetro (anti-scope)

- **Nuove feature** prodotto, **refactor massivo**, redesign `ExcelAnalyzer` / `GeneratedView` non motivato da blocker P0.
- **Sync silenziosa background**, nuovi **Timer / BGTask / Realtime / polling** obbligatori.
- **DDL / RLS / grant / migration** Supabase salvo **blocker** documentato come **task separato** approvato.
- **Dati reali** come **fixture in repo**, in **commit**, o in **evidence non redatte**.
- **Cleanup distruttivo** non scoped / non concordato con l’utente.
- **Claim** «production-ready», «production no-notes», «100% globale» — competenza **TASK-105** o chiusura formale successiva.
- **Fix immediati durante il collaudo**: se emerge un bug o una UX bloccante, la execution deve fermarsi e aprire una fix lane separata o un follow-up task; non mescolare accettazione reale e sviluppo non pianificato.
- **Ottimizzazioni UI/UX applicate al volo:** TASK-104 può classificare e pianificare ritocchi, ma non deve cambiare layout, copy, navigazione o logica durante la stessa acceptance reale.
- Modifiche **Android** o **Supabase** non strettamente necessarie al perimetro iOS (Android resta **parità**; patch Kotlin solo se blocker e scope esplicito).

---

## 8. Prerequisiti reali (prima di EXECUTION futura)

| Prerequisito | Nota |
|--------------|------|
| **iPhone** | Device fisico con build **Release** o equivalente accettato per negozio; batteria/rete stabili; storage sufficiente. |
| **Android** | Device fisico, stesso account/project Supabase; app reference già funzionante. |
| **Supabase live** | Istanza condivisa; **nessun** write da questo turno di planning; verificare stato servizio prima di execution. |
| **Versioni app / build** | Annotare commit Git, build configuration, versione app e device OS per iOS e Android prima del test. |
| **Rete / energia / storage** | Wi‑Fi o rete dati stabile, batteria sufficiente o alimentazione, spazio libero sufficiente per import/export reali. |
| **Account / sessione** | Utente disponibile per login e verifica owner/RLS; account non condiviso con dati non pertinenti al test se evitabile. |
| **Backup** | Backup/export **negozio** o piano di rollback concordato **prima** di mutazioni su dati reali. Deve essere chiaro chi può ripristinare e da dove. |
| **Consenso dati reali** | Dichiarazione esplicita (tracciabile) che file Excel e record possono essere usati per il collaudo e come verranno redatti. |
| **Excel reali** | File forniti dall’utente; **non** committati nel repo; preferire una coppia small/large rappresentativa ma non eccessiva per il primo giro. |
| **Set campione controllato** | Identificare 3–5 prodotti reali “sentinella” da seguire end-to-end, con valori redatti nelle evidenze. |
| **Baseline sentinelle** | Definire prima del test quali campi verificare per ogni sentinella: presenza, nome redatto, categoria/fornitore redatti, current/previous purchase/retail, pending/outbox. |
| **Finestra operativa** | Eseguire fuori dal momento di massima attività del negozio, così eventuali stop/rollback non bloccano lavoro reale. |
| **Privacy / redaction** | Processo per screenshot, log, manifest (hash, conteggi, prefissi redatti). |
| **Criteri verdict condivisi** | Prima di iniziare, chiarire con l’utente cosa significa **PASS**, **PASS_WITH_NOTES**, **PARTIAL** e **BLOCKED**. |
| **Timebox / pausa** | Definire una durata massima ragionevole per il collaudo e un punto sicuro di pausa/ripresa. |
| **Responsabile decisioni** | Chiarire chi decide consenso, rollback/cleanup, accettazione fallback scanner e chiusura con note. |
| **Single-writer concordato** | Decidere quale device muta per primo e quale resta read-only durante ogni round-trip. |
| **Lingua operativa** | Stabilire lingua/interfaccia usata nel test reale per valutare copy e recovery in modo realistico. |
| **Gestione artefatti** | Concordare destino di export, screenshot, log e file temporanei: eliminare, redigere o conservare fuori repo. |

---

## 9. Regole consenso dati reali

1. **Nessun** dato reale in evidenze **non redatte** (barcode prodotto, ragione sociale, prezzi identificabili, PII).
2. **Nessun** dato reale **committato** in git (inclusi allegati Excel).
3. **Screenshot / log:** sempre crop, blur, oppure sostituzione con **descrizione strutturale** (es. «N righe», «file ~X MB»).
4. **Prima** di usare file o snapshot DB reali in EXECUTION: **conferma esplicita utente** registrata (es. riga in `01-consent-and-privacy.md` con data, **senza** contenuto sensibile).
5. Se il consenso non è documentabile in modo sicuro → **STOP** (vedi §14).
6. Per i prodotti sentinella usare identificatori redatti stabili, per esempio `SENTINEL-A`, `SENTINEL-B`, invece di barcode/nome reale. La mappatura reale resta fuori repo e non va riportata nelle evidenze.
7. Se una schermata contiene troppi dati reali per essere redatta in sicurezza, sostituire screenshot con descrizione testuale strutturata: schermata, azione, risultato atteso, risultato osservato.

8. Il consenso deve essere revocabile: se l’utente interrompe o revoca l’uso dei dati reali, la execution passa subito a **STOP / PARTIAL** e registra solo metadati redatti.
9. Minimizzare sempre il dataset reale: usare il file grande solo dopo PASS del file piccolo e dopo conferma che il rischio operativo è accettabile.

---

## 10. Micro-slice consigliate (S104-A … S104-W)

| ID | Nome | Contenuto operativo (pianificato) |
|----|------|-----------------------------------|
| **S104-A** | Preflight / consent / backup / privacy | Checklist consenso, backup, redaction policy, ruoli operativi; nessuna mutazione finché A non è PASS documentale. |
| **S104-B** | Device / account / session real setup | Build/install iOS+Android; login; verifica stesso project hash / owner hash **redatto**; stato rete. |
| **S104-C** | Real Excel **small** import iOS | Import da file picker/provider reale; analisi colonne; nessun incollaggio di path utente in chiaro nelle evidenze. |
| **S104-D** | PreGenerate → Generated → edit / save history | Flusso completo inventario su dati reali; salvataggio `HistoryEntry`. |
| **S104-E** | Scanner reale + **fallback** manuale | Camera; se fallisce o non accettabile → fallback documentato utente **ACCEPTED**. |
| **S104-F** | iOS product/price edit + ProductPrice current/previous | Modifica su `DatabaseView` o percorso equivalente; baseline **pre/post** sentinelle; verifica storico vs UI. |
| **S104-G** | **iOS → Supabase → Android** real flow | Push/apply come da UX Release; read-back su Android **redatto**. |
| **S104-H** | **Android → Supabase → iOS** real flow | Mutazione Android controllata; pull/sync iOS; verifica locale. |
| **S104-I** | Real export / share Excel | Export; condivisione (AirDrop/Mail/etc.) **solo** se sicuro; file non in repo. |
| **S104-J** | Offline/retry breve + pending/outbox/sync summary | Rete off/on; pending non bloccante; summary coerente con TASK-091…096. |
| **S104-K** | UX friction log / operator notes | Raccogliere frizioni reali: copy poco chiaro, CTA nascoste, stati loading/error, passaggi troppo lunghi. Nessuna patch in execution; solo follow-up classificati P0/P1/P2. |
| **S104-L** | Rollback / cleanup decision | Decidere cosa resta come dato reale valido, cosa va annullato, e come verificare nessun residuo indesiderato. Cleanup solo concordato. |
| **S104-M** | Evidence pack + final decision | Compilazione ledger CA-104; verdict **senza** claim TASK-105. |
| **S104-N** | User acceptance script | Preparare una mini-checklist finale che l’utente possa confermare: “lo userei domani in negozio?” con note residue. |
| **S104-O** | Planning closeout / next-task routing | Decidere se le note residue vanno in TASK-105, in un eventuale TASK-106 UX polish, o in bugfix dedicato; nessun nuovo task aperto automaticamente. |
| **S104-P** | Planning review hardening | Review indipendente del piano: coerenza MASTER, riferimenti sezione, criteri verdict, anti-scope e privacy prima di qualunque handoff execution. |
| **S104-Q** | Evidence template readiness | Preparare struttura template e campi obbligatori, senza risultati inventati e senza file reali allegati. |
| **S104-R** | Risk register / contingency review | Mappare rischi P0/P1/P2 e contromisure prima di execution; nessun rischio P0 senza stop/rollback/follow-up definito. |
| **S104-S** | Conflict / stale baseline guard | Pianificare verifica **no silent overwrite**: se current/previous o remote state non combaciano con baseline, **fermare** e richiedere **review manuale**. |
| **S104-T** | File provider / share source review | Mappare origine dei file reali e fallback sicuri: Files, iCloud, condivisione, locale; **nessun path reale** in evidenza. |
| **S104-U** | Single-writer / concurrency guard | Pianificare ordine delle mutazioni iOS/Android e **vietare** modifiche concorrenti sulle **stesse sentinelle**. |
| **S104-V** | Artifact cleanup / retention plan | Definire destino di export, screenshot, log e cache: **nessun** dato reale o path personale in repo. |
| **S104-W** | Operational language / copy review | Verificare **lingua reale** dell’operatore, copy di **recovery** e assenza di testi tecnici **bloccanti**. |

Ordine suggerito: **A → B** gate obbligatori; poi **C–J** in sequenza logica con dipendenze; **K–O** chiusura controllata, rollback/cleanup, verdict, accettazione utente e routing note residue. **P–W** servono solo a rafforzare planning/review, template, **conflict/stale guard**, **file-provider readiness**, **single-writer**, **artifact cleanup** e **copy operativo** **prima** dell’eventuale handoff execution (non sostituiscono il protocollo operativo §18).

---

## 11. Acceptance criteria — CA-104-01 … CA-104-39

*(Stato pianificato: tutti `PLANNED` fino a EXECUTION; nessun PASS inventato in planning.)*

| ID | Descrizione | Tipo verifica prevista (execution) |
|----|-------------|-------------------------------------|
| **CA-104-01** | **Consenso** dati reali documentato **prima** di import/sync mutativi | Documentale + traccia utente |
| **CA-104-02** | **Backup** o piano rollback concordato | Documentale |
| **CA-104-03** | **Privacy:** evidenze redatte; scan no-secrets | Statico / review |
| **CA-104-04** | **Device** iOS fisico operativo | MANUAL / device |
| **CA-104-05** | **Device** Android fisico operativo | MANUAL / device |
| **CA-104-06** | **Login/sessione** reale funzionante su entrambi | MANUAL |
| **CA-104-07** | **Import Excel reale piccolo** iOS end-to-end | MANUAL |
| **CA-104-08** | **Import Excel reale grande** iOS (stress operativo accettabile) | MANUAL |
| **CA-104-09** | **PreGenerate** corretto su file reale | MANUAL |
| **CA-104-10** | **Generated:** edit righe, salvataggio stato | MANUAL |
| **CA-104-11** | **Cronologia** / `HistoryEntry` coerente post-save | MANUAL |
| **CA-104-12** | **Scanner** reale **PASS** **oppure** **fallback** manuale **ACCEPTED** da utente | MANUAL |
| **CA-104-13** | **Database** edit prodotto/prezzo iOS | MANUAL |
| **CA-104-14** | **ProductPrice** current/previous coerenti iOS↔Supabase↔Android | MANUAL + read-back redatto |
| **CA-104-15** | **iOS → Supabase → Android** almeno un ciclo completo **PASS** | MANUAL |
| **CA-104-16** | **Android → Supabase → iOS** almeno un ciclo completo **PASS** | MANUAL |
| **CA-104-17** | **Export** Excel reale **PASS** | MANUAL |
| **CA-104-18** | **Offline/retry** breve; **pending/outbox** senza stallo inspiegato; nessuna **perdita** o **duplicato grave** non spiegato | MANUAL |
| **CA-104-19** | **UX friction log** compilato con severità P0/P1/P2 e decisione: accettato, follow-up, blocker | MANUAL / review |
| **CA-104-20** | **Rollback/cleanup** deciso e verificato: nessun residuo indesiderato o residuo reale intenzionale documentato | MANUAL / read-back redatto |
| **CA-104-21** | **Performance percepita** accettabile su file reale small/large: niente freeze prolungati senza feedback, tempi sostenibili per lavoro negozio | MANUAL |
| **CA-104-22** | **User acceptance finale**: utente conferma se il flusso è usabile nel negozio e quali note restano | Conferma utente |
| **CA-104-23** | **Build/run traceability** completa: commit/build/versione/device/rete/sessione redatti registrati | Documentale |
| **CA-104-24** | **Decision log** coerente: ogni deviazione dal piano ha motivo, scelta e impatto su verdict | Review |
| **CA-104-25** | **Routing note residue**: ogni nota P0/P1/P2 ha destinazione chiara: accettata, TASK-105, TASK-106/follow-up, bugfix | Review |
| **CA-104-26** | **Owner/RLS sanity check** documentato prima di mutazioni reali bidirezionali | Review / read-only check |
| **CA-104-27** | **Scanner verdict separato**: hardware pass oppure fallback accepted con nota esplicita | MANUAL |
| **CA-104-28** | **Template evidence readiness**: campi obbligatori pronti, nessun risultato fittizio, nessun dato reale allegato | Planning review |
| **CA-104-29** | **Planning review consistency**: riferimenti sezione, MASTER, status, anti-scope e DoD coerenti | Planning review |
| **CA-104-30** | **Timebox / pause-resume** definito: ultimo step, stato dati, prossima azione sicura sempre ricostruibili | Planning review / execution notes |
| **CA-104-31** | **Risk register** compilato con mitigazione per privacy, owner/RLS, duplicati, import grande, scanner, export e cleanup | Planning review |
| **CA-104-32** | **Follow-up UX routing**: ogni proposta UI/UX ha severità, schermata, razionale, destinazione e non viene implementata in TASK-104 | Review |
| **CA-104-33** | **Baseline pre/post sentinelle** documentata: solo delta atteso, nessuna sovrascrittura silenziosa | Manual / read-back redatto |
| **CA-104-34** | **Conflict/stale guard**: mismatch current/previous, owner/RLS o remote state **blocca** mutazioni e richiede review | Review |
| **CA-104-35** | **File provider readiness**: origine file reale e fallback sicuro documentati **senza** path personali | Manual / review |
| **CA-104-36** | **Single-writer / concurrency guard**: ordine mutazioni iOS/Android definito, nessuna modifica concorrente sulle stesse sentinelle | Planning review / execution notes |
| **CA-104-37** | **Sequenza temporale round-trip** ricostruibile: pre-read, mutate, sync/push, remote read-back, other-client pull/read, post-check | Review |
| **CA-104-38** | **Artifact cleanup / retention** deciso: export, screenshot, log e cache non finiscono in repo e sono redatti/eliminati secondo consenso | Review |
| **CA-104-39** | **Lingua/copy operativo** valutato: recovery, sync, export, scanner e errori principali comprensibili nella lingua usata | Manual / UX review |

---

## 12. Evidence pack pianificato

**Cartella:** `docs/TASKS/EVIDENCE/TASK-104/`

**File previsti (template / intestazioni only in planning; NON popolati con risultati ora):**

| File | Scopo |
|------|--------|
| `00-summary.md` | Ledger CA-104, stato run, hash redatti, link alle altre evidenze. |
| `01-consent-and-privacy.md` | Consenso, limiti d’uso dati, policy redaction. |
| `02-device-account-preflight.md` | Device model/OS redatti, sessione, project hash, commit/build/versioni app, rete/energia/storage. |
| `03-real-excel-manifest-redacted.md` | Solo metadati redatti (dimensioni, fogli, n righe approssimate). |
| `04-ios-real-flow.md` | Passi iOS su dati reali (testo strutturato, no raw). |
| `05-android-real-flow.md` | Passi Android (testo strutturato). |
| `06-productprice-current-previous.md` | Tabella valori **placeholder** o redatti. |
| `07-export-share.md` | Metodo export; nessun path assoluto utente in chiaro. |
| `08-offline-retry-pending-outbox.md` | Comportamento osservato. |
| `09-privacy-redaction-scan.md` | Checklist scan pre-chiusura. |
| `10-ux-friction-log.md` | Frizioni UX reali, severità, follow-up consigliati; nessuna patch applicata in planning. |
| `11-rollback-cleanup.md` | Cosa è stato mantenuto, annullato o lasciato intenzionalmente; read-back redatto. |
| `12-user-acceptance.md` | Conferma finale utente e note residue. |
| `13-decision-log.md` | Deviazioni, motivi, decisioni e impatto su PASS/PARTIAL/BLOCKED. |
| `14-verdict-rules.md` | Definizioni operative **PASS** / **PASS_WITH_NOTES** / **PARTIAL** / **BLOCKED** condivise prima del test. |
| `15-user-acceptance-script.md` | Domande finali utente e checklist di accettazione pratica. |
| `16-risk-register.md` | Rischi P0/P1/P2 e contromisure concordate prima/durante execution. |
| `17-follow-up-routing.md` | Note residue e proposte UX instradate a TASK-105, TASK-106/follow-up o bugfix. |
| `18-baseline-sentinels.md` | Snapshot redatto pre/post delle sentinelle e delta attesi. |
| `19-conflict-stale-guard.md` | Regole e osservazioni per no silent overwrite, stale baseline, mismatch remote/local. |
| `20-file-provider-readiness.md` | Origine file reali, fallback provider e note privacy sui path. |
| `21-single-writer-sequence.md` | Ordine mutazioni iOS/Android, concurrency guard e sequenza temporale round-trip. |
| `22-artifact-cleanup-retention.md` | Destino export, screenshot, log, cache e conferma nessun dato reale in repo. |
| `23-operational-language-copy.md` | Lingua usata, copy di recovery e frizioni testuali UX. |
| `24-final-verdict.md` | Verdict TASK-104 (non globale); dipendenza TASK-105 esplicita. |

**In questo turno:** la cartella può non esistere o esistere vuota; **non** creare contenuti di risultato fittizi.

---

## 13. Go / No-Go per EXECUTION futura

**GO** solo se contemporaneamente:

- Planning review **PASS** (o override utente documentato verso EXECUTION).
- Consenso **CA-104-01** e backup **CA-104-02** pianificati/eseguibili.
- Device e account disponibili **CA-104-04…06**.
- Evidenze template accettate; redazione compresa.
- Prodotti sentinella e piano rollback/cleanup definiti prima di qualunque mutazione reale.
- Finestra operativa compatibile con eventuale stop senza impatto sul lavoro del negozio.
- Commit/build/versioni app e ambiente Supabase redatto identificabili prima dell’inizio.
- Percorso small-first confermato: nessun file grande prima di aver completato il flusso piccolo senza blocker P0.
- Definizioni **PASS** / **PASS_WITH_NOTES** / **PARTIAL** / **BLOCKED** accettate con l’utente **prima** di iniziare.
- **Owner/RLS sanity check** pianificato prima delle mutazioni bidirezionali.
- Timebox, pausa/ripresa e responsabile decisioni definiti.
- Risk register iniziale compilato con contingenza per ogni rischio P0.
- Baseline sentinelle definita e **conflict/stale guard** pianificato prima di mutazioni reali.
- Origine file reale e **fallback provider** documentabili **senza** path personali.
- **Single-writer** e **sequenza round-trip** concordati prima di modificare dati reali.
- **Piano artifact cleanup/retention** definito per export, screenshot, log e cache.
- **Lingua operativa** scelta e **copy recovery** valutabile dall’utente.

**NO-GO** se una qualsiasi:

- Consenso assente o ambiguo.
- Impossibilità di backup/rollback accettabile per l’utente.
- Blocco auth/RLS non risolvibile senza escalation schema (fuori scope).
- Mancanza di prodotti sentinella o impossibilità di verificare current/previous senza esporre dati sensibili.
- Utente non disponibile per conferma finale o per decisione rollback/cleanup.
- **Impossibilità** di distinguere chiaramente test scanner **hardware** da **fallback manuale**.
- **Evidenze template** non pronte o **rischio concreto** di salvare dati reali **in chiaro**.
- Nessun responsabile chiaro per decisioni su rollback/cleanup o fallback scanner.
- Mancanza di contingency plan per un rischio P0 già prevedibile.
- **Impossibilità** di stabilire **baseline sentinelle** o di verificare **delta** senza esporre dati sensibili.
- File reale accessibile solo tramite percorso/provider che **costringe** a registrare **path** o **metadati sensibili non redatti**.
- **Non** è possibile impedire modifiche **concorrenti** iOS/Android sulle **stesse sentinelle**.
- **Non** è chiaro dove finiscono export, screenshot, log o cache contenenti **dati reali**.
- L’utente **non** comprende lingua/copy dei passaggi **critici** e **non** può confermare azioni mutative.

---

## 14. Stop conditions

Interrompere EXECUTION e registrare **BLOCKED** / **PARTIAL** documentato se:

- **Consenso mancante** o revocato.
- **Backup mancante** per mutazioni su dati critici.
- **Dati reali** finiti in evidenza/git non redatti.
- **Rischio perdita dati** o operazione irreversibile non concordata.
- **Supabase** permission / RLS **blocker** non aggirabile lato client.
- **Pending/outbox** in stallo senza spiegazione UX né recovery.
- **Duplicati gravi** o incongruenze **ProductPrice** non spiegate.
- **Crash** reale ripetuto sul percorso P0.
- **UX P0**: un punto del flusso induce rischio concreto di perdita dati, doppio invio o scelta irreversibile non chiara.
- **Performance operativa non sostenibile**: freeze o tempi percepiti incompatibili con uso negozio senza feedback adeguato.
- **Tracciabilità insufficiente**: impossibile sapere quale build, device, account o run ha prodotto un risultato.
- **Deviazione non documentata** dal percorso previsto che rende il verdict non verificabile.
- **Owner/RLS incerto:** i client sembrano lavorare su owner/progetto diverso o non verificabile in modo privacy-safe.
- **Scanner ambiguo:** non è chiaro se il successo deriva da **camera reale** o da **input manuale**, rendendo **CA-104-12** / **CA-104-27** non valutabili.
- **Baseline sentinelle mismatch:** current/previous, owner, categoria/fornitore o pending/outbox divergono in modo **non spiegato**.
- **Provider file non sicuro:** il flusso costringe a esporre **path personali** o dati **non redatti** per procedere.
- **Mutazione concorrente:** iOS e Android modificano o stanno per modificare la **stessa sentinella** senza sequenza single-writer.
- **Artifact leak risk:** export, screenshot, log o cache con dati reali potrebbero finire in **repo** o evidenze **non redatte**.
- **Copy critico non compreso:** l’utente non capisce una conferma **distruttiva/mutativa** o uno **recovery step** e non può prendere decisione informata.
- **Timebox superato** senza possibilità di pausa sicura o senza stato dati ricostruibile.
- **Decision owner assente** quando serve scegliere rollback, cleanup, accettazione fallback o chiusura con note.
- Tentativo di dichiarare **100% pratico** / **production-ready** **prima** di review+utente.

---

## 15. Definition of Done (task completo)

DoD originaria per un pass con **dati reali negozio**. La chiusura effettiva 2026-05-12 usa override utente e verdict più stretto: **realistic shop acceptance PASS_WITH_NOTES** con dati sintetici privacy-safe, senza claim real-user/no-notes/global.

Il task **TASK-104** è **DONE** nel perimetro real-user/no-notes solo quando **tutti** i punti seguenti sono soddisfatti **e** l’utente conferma:

1. Almeno **1** ciclo **iOS → Supabase → Android** **PASS** con flusso **reale**.
2. Almeno **1** ciclo **Android → Supabase → iOS** **PASS** con flusso **reale**.
3. **Import/export reale** **PASS**.
4. **Scanner:** **PASS** hardware reale **oppure** **fallback manuale** accettato dall’utente, con verdict separato **SCANNER_HARDWARE_PASS** / **FALLBACK_MANUAL_ACCEPTED** tracciato in evidenze.
5. **ProductPrice** current/previous **coerenti** (con tolleranza/documentazione come TASK-103 se applicabile).
6. **Pending/outbox** senza stati **bloccanti** non spiegati.
7. **Evidenze** privacy-safe in `docs/TASKS/EVIDENCE/TASK-104/`.
8. **UX friction log** compilato e nessun P0 aperto non accettato.
9. **Rollback/cleanup** deciso e verificato.
10. **Build/run traceability** completa e verificabile.
11. **Decision log** completo per deviazioni e note residue.
12. **Owner/RLS sanity check**, **scanner verdict separato** e **template evidence** verificati.
13. **Risk register**, **timebox/pause-resume** e **follow-up routing** completati.
14. **Baseline sentinelle**, **conflict/stale guard** e **file-provider readiness** verificati.
15. **Single-writer**, **artifact cleanup/retention** e **lingua/copy operativo** verificati.
16. **Review finale** **APPROVED** + **conferma utente**.

**Nota review finale:** la chiusura TASK-104 attuale **non** autorizza la formula **«usabile nel negozio al 100% pratico»** perché non sono stati usati dati reali negozio.  
**NON** dichiarare ancora **«production no-notes»** — dipende da **TASK-105** o da un task successivo esplicito.

---


## 16. Contesto TASK-102 (note residue utili a TASK-104 / TASK-105)

Da **`docs/TASKS/TASK-102-release-polish-ux-ios.md`** e **`docs/TASKS/EVIDENCE/TASK-102/`** (es. `MATRIX-M102`, `smoke-regression-checklist`, limiti dichiarati in chiusura TASK-102):

- **Camera / scanner reale:** in TASK-102 gran parte del collaudo è stata **Simulator**; **TASK-104** deve coprire **hardware reale** o accettare fallback **esplicito**.
- **VoiceOver gestuale completo:** spesso **non** eseguito in TASK-102 — resta principalmente per **TASK-105**, ma TASK-104 può registrare **gap** se emergono in flussi negozio.
- **Files provider / selezione file host:** Simulator non sempre rappresentativo; TASK-104 valida **Document picker** reale.
- **Sync live reale:** TASK-102 ultimo pass **signed-out** su cloud in parte dei percorsi; TASK-104 esige **sessione reale** e round-trip.

---

## 17. UX / UI acceptance guidance per TASK-104

TASK-104 non deve introdurre redesign durante il collaudo, ma deve osservare e classificare la qualità dell’esperienza reale.

### 17.1 Principi UX da verificare

- **Azioni primarie sempre riconoscibili:** import, genera, salva, sincronizza, esporta e torna a Home devono essere ovvie senza ricordare passaggi precedenti.
- **Feedback immediato:** su import grande, export, sync e retry l’utente deve vedere stato/progresso o almeno un messaggio chiaro; evitare impressione di app bloccata.
- **Recovery chiara:** ogni errore deve indicare cosa fare dopo: riprova, controlla cloud, accedi di nuovo, correggi riga, esporta errori, usa input manuale.
- **Destructive action protette:** delete/rollback/discard/cleanup devono essere confermate e descritte in linguaggio operativo, non tecnico.
- **Scanner non obbligatorio:** se camera o permessi non funzionano in negozio, il fallback manuale deve essere abbastanza veloce da non bloccare il flusso.
- **Densità dati leggibile:** griglie e schermate database devono restare potenti ma non creare errori visivi; preferire note follow-up mirate invece di redesign completo.
- **Accessibilità pratica:** almeno le azioni principali devono restare leggibili e raggiungibili con testo grande ragionevole; eventuali problemi VoiceOver/Dynamic Type vanno classificati come P1/P2 salvo rischio operativo P0.
- **Riepilogo finale comprensibile:** dopo sync/export/import l’utente deve poter capire cosa è successo senza leggere log tecnici: elementi creati, aggiornati, errori, pending e prossima azione.

### 17.2 Classificazione frizioni UX

| Severità | Significato | Effetto sul task |
|----------|-------------|------------------|
| **P0** | Rischio perdita dati, doppio invio, azione irreversibile non chiara, blocco senza recovery | **BLOCKER** finché non esiste fix/follow-up approvato |
| **P1** | Flusso usabile ma lento/confuso; richiede spiegazione all’utente | Può chiudere **PASS WITH NOTES** se accettato |
| **P2** | Miglioramento estetico/copy/spaziatura, non blocca uso reale | Follow-up polish |

### 17.3 Decisione progettuale autonoma

Quando ci sono alternative equivalenti durante planning/review, scegliere la soluzione più coerente con iOS:

- preferire `NavigationStack`, sheet, toolbar e confirmation dialog nativi;
- preferire copy breve e operativo rispetto a spiegazioni tecniche;
- mantenere le azioni mutative dietro conferma quando toccano dati reali;
- evitare nuovi concetti UI se una schermata esistente può ospitare l’azione in modo chiaro;
- non copiare layout Android 1:1: Android resta fonte funzionale, iOS resta target UX nativo.

### 17.4 Ritocchi UX da proporre solo come follow-up

Se durante il collaudo emergono frizioni non bloccanti, classificarle come proposte di follow-up senza applicarle in TASK-104:

- copy più operativo su errori cloud/import/export;
- CTA primaria più evidente quando l’utente deve sincronizzare o esportare;
- progress/overlay più chiaro su file grandi;
- fallback scanner/manual input più rapido;
- riepilogo finale sync più leggibile per utente non tecnico;
- migliore separazione visiva tra azioni sicure, mutative e distruttive;
- stato finale sync/import/export più leggibile con conteggi e una CTA primaria chiara;
- empty/error state più guidati quando non ci sono risultati, non ci sono pending o il cloud è bloccato.

Decisione consigliata: se il ritocco è **P2 estetico/copy**, mandarlo a polish post-acceptance; se è **P1 operativo**, può andare in TASK-105 o TASK-106; se è **P0**, blocca TASK-104 o richiede fix lane separata.

---

## 18. Protocollo operativo consigliato per futura EXECUTION

Questa sezione serve a rendere il collaudo efficiente e ridurre rischio su dati reali.

1. **Preparazione:** conferma consenso, backup, device, account, rete, prodotti sentinella.
2. **Dry run non mutativo:** aprire app, verificare login/sessione, leggere stato cloud, controllare che l’utente riconosca schermate e azioni; registrare subito eventuali frizioni UX P0/P1/P2.
3. **Import small:** eseguire il flusso completo con file reale piccolo; fermarsi se mapping/header non è chiaro.
4. **Sentinelle:** scegliere 3–5 prodotti reali e seguire solo quelli nelle evidenze redatte.
5. **Round-trip bidirezionale:** eseguire iOS→Android e Android→iOS con controlli current/previous, ma solo dopo owner/RLS sanity check privacy-safe; procedere con **single-writer**: **un client muta**, l’altro resta in **lettura/verifica** finché la mutazione e il read-back non sono confermati.
6. **Import large:** validare sostenibilità operativa e feedback UI; non forzare se il negozio è operativo e il rischio è alto.
7. **Export/share:** verificare che il file prodotto sia apribile e abbia contenuto atteso, senza conservarlo nel repo.
8. **Offline/retry:** test breve e reversibile; non simulare failure distruttive.
9. **Rollback/cleanup:** decidere con l’utente se i dati reali creati/modificati restano validi o vanno annullati; includere anche **destino** di export, screenshot, log e **cache** locali (eliminazione, redazione o conservazione fuori repo).
10. **Accettazione utente:** compilare conferma finale e note residue.

---

## 19. Ruoli, manifest run e strategia efficiente

### 19.1 Ruoli durante execution futura

| Ruolo | Responsabilità |
|-------|----------------|
| **Utente / Operatore negozio** | Fornisce consenso, seleziona file reali, conferma valori sentinella, decide rollback/cleanup e accettazione finale. |
| **Executor** | Guida il protocollo, registra evidenze redatte, non forza decisioni rischiose, ferma il test su stop condition. |
| **Reviewer** | Verifica evidence pack, privacy, ledger CA-104 e coerenza del verdict senza assumere vero il report execution. |

### 19.2 Manifest run minimo

Ogni run reale deve avere un identificatore redatto e stabile, per esempio:

```text
TASK104_REALSHOP_<YYYYMMDD>_<RUN-N>
```

Il manifest deve includere solo metadati privacy-safe:

- data/ora locale;
- device iOS/Android e OS redatti;
- commit/build/versione app iOS e Android;
- project hash Supabase redatto;
- owner/session hash redatto;
- file small/large con dimensioni e righe approssimate, senza nomi reali;
- prodotti sentinella `SENTINEL-A…E`;
- stato finale: PASS / PASS_WITH_NOTES / PARTIAL / BLOCKED.

### 19.3 Strategia efficiente

Per evitare collaudi lunghi e rischiosi:

1. **Small-first:** completare tutto il round-trip con file piccolo prima del file grande.
2. **Sentinelle-first:** controllare pochi prodotti rappresentativi invece di inseguire tutto il dataset.
3. **Una sola fonte di evidenza per fatto:** evitare screenshot duplicati; preferire ledger strutturato e read-back redatto.
4. **No retry ciechi:** ogni retry deve avere causa probabile e risultato atteso.
5. **Stop precoce:** un P0 reale vale più di dieci PASS parziali; fermarsi e documentare.

### 19.4 Definizioni verdict TASK-104

| Verdict | Significato pratico |
|---------|---------------------|
| **PASS** | Tutti i CA richiesti sono soddisfatti, nessun P0/P1 aperto non accettato, utente conferma uso negozio. |
| **PASS_WITH_NOTES** | Flusso reale usabile; restano note P1/P2 accettate e instradate, nessun P0 aperto. |
| **PARTIAL** | Parte del flusso reale è valida, ma uno o più CA non sono completati per vincoli hardware, tempo, consenso, ambiente o note non bloccanti ma non chiudibili. |
| **BLOCKED** | Stop condition attiva: consenso/backup/privacy/RLS/perdita dati/crash/UX P0 o tracciabilità insufficiente. |

### 19.5 Script minimo di accettazione utente

Alla fine della futura execution, l’utente deve poter rispondere in modo pratico, non tecnico:

1. “Con questo flusso posso importare un file reale del negozio senza paura di perdere dati?”
2. “Riesco a capire quando devo sincronizzare, esportare o correggere errori?”
3. “Il fallback manuale è sufficiente se lo scanner non funziona?”
4. “I prezzi current/previous che vedo su iOS/Android sono coerenti con ciò che mi aspetto?”
5. “Domani lo userei in negozio? Se sì, con quali note?”

Le risposte vanno redatte e salvate in `15-user-acceptance-script.md` durante execution futura.

### 19.6 Owner/RLS sanity checklist privacy-safe

Prima di qualunque mutazione reale bidirezionale, la futura execution deve confermare senza esporre dati sensibili:

1. iOS e Android puntano allo stesso project hash Supabase redatto;
2. entrambi i client risultano autenticati con sessione valida;
3. owner/session hash redatti sono coerenti con il perimetro previsto;
4. una lettura non distruttiva mostra dati attesi o stato vuoto coerente;
5. nessun client mostra dati di un owner diverso o non spiegabile;
6. se la verifica è ambigua, la mutazione reale resta **NO-GO**.

Questa checklist deve restare **read-only**: niente SQL mutativo, niente service role, niente bypass RLS, niente dump dati reali.

### 19.7 Scanner / fallback decision tree

Durante execution futura, separare sempre hardware camera da fallback manuale:

| Caso | Verdict scanner | Effetto |
|------|-----------------|---------|
| Camera legge barcode reale e apre il flusso corretto | **SCANNER_HARDWARE_PASS** | CA scanner pienamente soddisfatta |
| Camera non disponibile/permesso negato ma input manuale è rapido e accettato | **FALLBACK_MANUAL_ACCEPTED** | Può chiudere con note se l’utente accetta |
| Camera fallisce e fallback è lento/confuso | **PARTIAL** o **BLOCKED** secondo severità | Richiede follow-up UX/hardware |
| Non è chiaro quale percorso sia stato usato | **BLOCKED_SCANNER_AMBIGUOUS** | CA-104-12/27 non valutabili |

Il fallback manuale non deve essere considerato “scanner PASS”; deve essere una decisione esplicita dell’utente.

### 19.8 Template evidence readiness checklist

Prima dell’handoff execution, i template evidence devono avere almeno questi campi vuoti, senza risultati inventati:

- run id redatto;
- data/ora e operatore;
- device/build/versioni;
- consenso/backup status;
- file small/large metadata redatti;
- prodotti sentinella;
- azione eseguita;
- risultato atteso;
- risultato osservato;
- screenshot/log redaction note;
- verdict locale della sezione;
- follow-up o stop condition.

Se questi campi non sono pronti, TASK-104 resta **ACTIVE / PLANNING** e non deve passare a execution.

### 19.9 Timebox / pause-resume protocol

Il collaudo reale non deve diventare una sessione infinita o confusa. Prima di execution futura definire:

- durata massima indicativa della sessione;
- step minimo che permette una pausa sicura;
- stato dati da registrare prima della pausa;
- chi decide se continuare, fermare o rimandare;
- cosa fare se il negozio deve tornare operativo subito;
- come riprendere senza ripetere azioni mutative già completate.

Formato minimo di pausa sicura:

```text
PAUSE_POINT:
- run_id:
- last_completed_slice:
- data_state: no_mutation / mutation_pending_review / mutation_committed / cleanup_pending
- pending_user_decision:
- next_safe_action:
- risks_open:
```

### 19.10 Follow-up UX routing format

Ogni proposta UI/UX emersa in TASK-104 deve essere tracciata senza implementazione immediata:

| Campo | Descrizione |
|-------|-------------|
| **ID** | `UX104-xx` |
| **Schermata** | Home, PreGenerate, Generated, Database, Options, Export, Scanner, ecc. |
| **Severità** | P0 / P1 / P2 |
| **Problema osservato** | Descrizione breve e privacy-safe |
| **Decisione consigliata** | TASK-105, TASK-106/follow-up, bugfix dedicato, accettato/no action |
| **Razionale UX** | Perché migliora chiarezza, fluidità, sicurezza o coerenza iOS |
| **Bloccante TASK-104?** | sì/no |

Decisione progettuale: i ritocchi UX P1/P2 non devono bloccare TASK-104 se il flusso reale è usabile e l’utente li accetta come note; i P0 bloccano o richiedono fix lane separata.

### 19.11 Baseline sentinelle / no silent overwrite

Per ogni sentinella usare solo campi redatti e confronti **delta**:

| Campo | Pre-run | Post-run | Delta atteso | Esito |
|-------|---------|----------|--------------|-------|
| `SENTINEL-A` presenza | redatto | redatto | invariato / creato / aggiornato | PLANNED |
| current purchase | redatto/hash/rounded | redatto/hash/rounded | atteso | PLANNED |
| previous purchase | redatto/hash/rounded | redatto/hash/rounded | atteso | PLANNED |
| current retail | redatto/hash/rounded | redatto/hash/rounded | atteso | PLANNED |
| previous retail | redatto/hash/rounded | redatto/hash/rounded | atteso | PLANNED |
| pending/outbox | count/status | count/status | atteso | PLANNED |

Regola: se il post-run non corrisponde al delta atteso, la futura execution deve fermare ulteriori mutazioni e registrare **PARTIAL** o **BLOCKED** finché il mismatch non è spiegato.

### 19.12 File provider / privacy source checklist

Prima di importare file reali, documentare solo metadati sicuri:

- origine: Files / iCloud / Share Sheet / locale / altro;
- tipo file: xlsx / xls / html-excel / altro;
- dimensione approssimata;
- numero righe/fogli approssimato;
- permesso lettura disponibile sì/no;
- fallback possibile sì/no;
- path personale registrato: deve restare **NO**.

Se il provider richiede passaggi manuali non ripetibili o espone path sensibili, registrare follow-up UX/Ops e **non** forzare l’import grande.

### 19.13 Single-writer sequence

Per ogni round-trip reale usare una sequenza esplicita:

```text
ROUND_TRIP_SEQUENCE:
- direction: iOS_TO_ANDROID / ANDROID_TO_IOS
- writer_client: iOS / Android
- reader_client: iOS / Android
- sentinel_ids: SENTINEL-A, SENTINEL-B, ...
- pre_read_done: yes/no
- mutation_done: yes/no
- push_or_sync_done: yes/no
- remote_read_back_done: yes/no
- reader_pull_or_read_done: yes/no
- post_check_done: yes/no
- concurrent_mutation_detected: must_be_no
```

---

## 20. Planning Review checklist

Prima di promuovere TASK-104 verso **READY FOR EXECUTION**, la Planning Review deve verificare:

| Check | Criterio |
|-------|----------|
| **Status** | MASTER e task file dicono entrambi **TASK-104 ACTIVE / PLANNING**, **NON DONE**, **NON READY FOR EXECUTION**. |
| **Anti-scope** | Nessuna richiesta implicita di Swift/Kotlin/SQL/build/test/runtime/write Supabase. |
| **Privacy** | Nessun dato reale, path personale, barcode, prezzo identificabile o screenshot non redatto nei template. |
| **Evidence** | Template pronti, ma senza risultati fittizi. |
| **Verdict** | PASS/PASS_WITH_NOTES/PARTIAL/BLOCKED definiti e coerenti con DoD/stop conditions. |
| **UX** | Frizioni P0/P1/P2, scanner/fallback e azioni distruttive hanno criteri chiari. |
| **Owner/RLS** | Esiste una verifica read-only prima delle mutazioni bidirezionali. |
| **Baseline** | Sentinelle, delta attesi e no silent overwrite sono pianificati. |
| **File provider** | Origine file reale e fallback sono documentabili senza path personali. |
| **Handoff** | Execution richiede override utente esplicito; TASK-105 resta non aperto. |

Esito Planning Review ammesso: **PASS**, **PASS_WITH_NOTES**, oppure **CHANGES_REQUESTED**. Non usare **DONE** in Planning Review.

---

## 21. Risk register iniziale

| ID | Rischio | Severità default | Mitigazione planning |
|----|---------|------------------|----------------------|
| **R104-01** | Dati reali finiscono in evidenze o git | P0 | Redaction policy, template vuoti, privacy scan, nessun file reale in repo. |
| **R104-02** | Owner/RLS non coerente tra iOS e Android | P0 | Owner/RLS sanity check read-only prima di mutazioni. |
| **R104-03** | Import grande blocca uso negozio | P1/P0 | Small-first, timebox, pausa sicura, feedback UI osservato. |
| **R104-04** | Duplicati o ProductPrice current/previous incoerenti | P0/P1 | Sentinelle, read-back redatto, stop su mismatch non spiegato. |
| **R104-05** | Scanner camera non funziona in ambiente reale | P1 | Verdict scanner separato e fallback manuale accettato esplicitamente. |
| **R104-06** | Export/share produce file errato o non apribile | P1 | Check apribilità e contenuto atteso senza salvare file in repo. |
| **R104-07** | Cleanup/rollback ambiguo | P0 | Responsabile decisione, evidence `11-rollback-cleanup.md`, stop se non decidibile. |
| **R104-08** | Utente non riesce a interpretare stato sync/import/export | P1 | UX friction log, riepilogo finale comprensibile, follow-up routing. |
| **R104-09** | Sessione lunga causa errori operativi o decision fatigue | P1 | Timebox, pause point, stop precoce e ripresa documentata. |
| **R104-10** | Baseline sentinelle non definita o mismatch non spiegato | P0/P1 | Baseline pre/post, no silent overwrite, stop su delta inatteso. |
| **R104-11** | File provider reale espone path sensibili o fallback non ripetibile | P1 | Checklist provider, niente path in evidenza, follow-up UX/Ops. |

Il risk register iniziale è planning-only: nessun rischio è considerato risolto finché non esiste evidence reale in execution futura.

---

## 22. Prompt di estensione coerente

Per estendere TASK-104 senza rompere il perimetro Planning, usare prompt di questo tipo:

```text
Estendi SOLO il PLANNING di TASK-104.
Non eseguire implementation/execution, non modificare Swift/Kotlin/SQL, non fare build/test/runtime, non scrivere su Supabase e non usare dati reali.
Leggi il file task TASK-104 e integra una nuova sezione/matrice per [AREA], mantenendo:
- TASK-104 ACTIVE / PLANNING
- TASK-104 NON DONE
- TASK-104 NON READY FOR EXECUTION
- TASK-105 non aperto
- nessun claim production-ready globale
Aggiungi criteri concreti, evidenze privacy-safe, stop conditions e UX guidance se rilevante.
```


Aree sensate da estendere in follow-up planning:

- **script operatore dettagliato** passo-passo per il giorno del collaudo;
- **template evidence** con intestazioni precompilate ma senza risultati;
- **checklist redaction** più severa per screenshot/log;
- **piano rollback specifico Supabase/SwiftData** senza SQL mutativo in planning;
- **criteri performance percepita** per import/export large;
- **mappa frizioni UX → follow-up TASK-105 o TASK-106**;
- **manifest run** con campi obbligatori, **template verdict rules** e **user acceptance script** pronti per execution;
- **decision log template** per deviazioni, retry e stop condition;
- **matrice P0/P1/P2 UX** collegata a TASK-105/TASK-106;
- **owner/RLS sanity checklist** privacy-safe prima delle mutazioni reali;
- **scanner/fallback decision tree** per separare hardware pass da fallback accepted;
- **Planning Review checklist** con criteri PASS/PASS_WITH_NOTES/CHANGES_REQUESTED.
- **risk register e contingency plan** con timebox/pause-resume;
- **follow-up UX routing template** con ID `UX104-xx`;
- **baseline sentinelle** e **no silent overwrite** template per ProductPrice current/previous;
- **file provider readiness** checklist per Files/iCloud/Share Sheet senza path personali.

---

## 23. Handoff

| Voce | Valore |
|------|--------|
| **Prossima fase** | **EXECUTION** *(override utente ricevuto in questo turno)* |
| **Prossimo agente** | **Codex / Executor** |
| **Prossima azione** | Eseguire TASK-104 end-to-end dove l'ambiente lo consente, creare evidence pack privacy-safe, marcare ogni CA-104-01…39 con stato chiaro e compilare handoff post-execution verso **Claude / Reviewer** senza aprire TASK-105 né dichiarare claim globali. |

---

## 24. Execution — Codex

### Avvio execution — 2026-05-12 20:41 -0400

**Obiettivo compreso:** eseguire TASK-104 nel perimetro approvato, con evidenze privacy-safe e ledger completo CA-104-01…39. I risultati non verificabili con device/file/account/consenso disponibili nell'ambiente saranno marcati `PARTIAL`, `BLOCKED` o `SKIPPED_WITH_REASON`, senza inventare `PASS`.

**Override utente:** l'utente ha dichiarato il piano definitivo approvato e ha richiesto esplicitamente l'intera fase di EXECUTION. Questo supera il gate planning-only precedente, ma non supera i requisiti di consenso, backup, device fisici, file reali e user acceptance finale: tali requisiti devono comunque essere verificati o marcati come non eseguibili.

**File da modificare previsti:**

| Path | Motivo |
|------|--------|
| `docs/MASTER-PLAN.md` | Tracking fase/responsabile TASK-104. |
| `docs/TASKS/TASK-104-real-shop-acceptance-ios-supabase-android.md` | Tracking execution e handoff post-execution. |
| `docs/TASKS/EVIDENCE/TASK-104/*.md` | Evidence pack privacy-safe TASK-104. |

**Piano minimo di intervento:**

1. Promuovere tracking a `ACTIVE / EXECUTION`, mantenendo TASK-104 `NON DONE` e TASK-105 non aperto.
2. Creare/populare evidence pack `docs/TASKS/EVIDENCE/TASK-104/` con stati reali, privacy-safe.
3. Eseguire preflight ambiente: repo, device, account/sessione, Supabase, file Excel disponibili, privacy.
4. Eseguire build/test/check realistici e validazioni read-only/mutative solo se sicure e consentite.
5. Compilare ledger CA-104-01…39 con stati finali e handoff a `ACTIVE / REVIEW`.

**Stato iniziale verificato:**

| Check | Esito |
|-------|-------|
| MASTER indica TASK-104 come task attivo | `ACTIVE / PLANNING` prima dell'override. |
| File task reale corrisponde al path del MASTER | Sì: `docs/TASKS/TASK-104-real-shop-acceptance-ios-supabase-android.md`. |
| TASK-104 non DONE | Confermato. |
| TASK-104 non ready for execution prima dell'override | Confermato. |
| TASK-105 non aperto | Confermato: nessun file task `TASK-105` trovato. |

### Log execution

| Timestamp | Azione | Esito |
|-----------|--------|-------|
| 2026-05-12 20:41 -0400 | Lettura obbligatoria MASTER, TASK-104, TASK-103, evidenze TASK-103, AGENTS iOS/Android/Supabase e Supabase changelog. | Completata; nessun codice modificato. |
| 2026-05-12 20:41 -0400 | Promozione tracking TASK-104 a `ACTIVE / EXECUTION` per override utente. | Completata; TASK-104 resta `NON DONE`; TASK-105 non aperto. |
| 2026-05-12 20:56 -0400 | Execution build/test/device/privacy/evidence. | iOS/Android build+smoke eseguiti; Supabase read-only PARTIAL; nessuna write; evidence pack completo; verdict proposto `PARTIAL`. |

---

## 25. Handoff post-execution

| Voce | Valore |
|------|--------|
| **Prossima fase** | **REVIEW** |
| **Prossimo agente** | **Claude / Reviewer** |
| **Handoff** | **READY FOR REVIEW** |
| **Verdict proposto** | **PARTIAL** |
| **Stato task** | **ACTIVE**, **NON DONE** |

### Obiettivo compreso

Eseguire TASK-104 end-to-end dove l'ambiente lo consente, senza inventare esiti: device/build/test/privacy e preflight sono stati eseguiti; i flussi real-shop che richiedevano consenso file-specifico, backup, sentinelle e owner/sessione live sono stati marcati `PARTIAL`/`BLOCKED`.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-104-real-shop-acceptance-ios-supabase-android.md`
- `docs/TASKS/TASK-103-final-real-device-cross-platform-acceptance-ios-supabase-android.md`
- `docs/TASKS/EVIDENCE/TASK-103/00-summary.md`
- `docs/TASKS/EVIDENCE/TASK-103/12-final-verdict.md`
- `docs/CODEX-EXECUTION-PROTOCOL.md`
- AGENTS iOS / Android / Supabase
- Codice iOS rilevante per Supabase config, ProductPrice, manual sync, import/export e localizzazioni
- Codice Android/build config/test rilevanti per import/export e app launch

### Piano minimo

1. Chiudere tracking execution verso review senza marcare DONE.
2. Popolare `docs/TASKS/EVIDENCE/TASK-104/` con 25 file privacy-safe.
3. Validare build/test/device smoke iOS e Android.
4. Eseguire solo Supabase read-only sicuro; nessuna mutazione senza gate reali.
5. Compilare ledger CA-104-01...39 e rischi residui.

### Modifiche fatte

- Aggiornato `docs/MASTER-PLAN.md` da TASK-104 `ACTIVE / EXECUTION` a `ACTIVE / REVIEW`, responsabile `Claude / Reviewer`, `READY FOR REVIEW`, verdict proposto `PARTIAL`.
- Aggiornato questo file task nelle sole parti di tracking/execution/handoff Codex.
- Creato evidence pack reale privacy-safe `docs/TASKS/EVIDENCE/TASK-104/` con tutti i file `00-summary.md` ... `24-final-verdict.md`.
- Nessuna modifica a codice Swift, Kotlin, SQL, schema, RLS, migration, backend o configurazioni runtime.

### Check eseguiti

| Check | Stato | Esito |
|-------|-------|-------|
| Build compila iOS | ✅ ESEGUITO | Release simulator build/run PASS; Release physical iPhone build/install/launch PASS. |
| Build/test Android | ✅ ESEGUITO | `assembleDebug testDebugUnitTest` PASS; targeted import/export tests PASS; physical install/launch smoke PASS. |
| XCTest mirati iOS | ✅ ESEGUITO | Supabase config/security, ProductPrice push/apply, manual sync, release UI, TASK-103 regression PASS con skip live-gated attesi. |
| Import/export sintetico | ✅ ESEGUITO | iOS synthetic analyzer/benchmark PASS; Android export/import tests PASS. |
| Supabase read/write/read-back | ⚠️ NON ESEGUIBILE integralmente | Read-only metadata/RLS PARTIAL; nessuna write per mancanza di consenso file-specifico, backup, sentinelle, owner/sessione live e successiva auth/circuit-breaker CLI. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Nessun codice modificato; warning osservati sono preesistenti/toolchain. |
| Modifiche coerenti con planning | ✅ ESEGUITO | Scope limitato a tracking/evidence e validazioni autorizzate; TASK-105 non aperto. |
| Criteri di accettazione verificati | ✅ ESEGUITO | CA-104-01...39 compilati in `00-summary.md`; molti sono `PARTIAL`/`BLOCKED`, nessun PASS inventato. |
| Privacy/segreti/evidence scan | ✅ ESEGUITO | Evidence TASK-104 scan PASS; scan esteso rileva solo path storici e parole policy in MASTER/TASK planning, non leak nel pack TASK-104. |
| `git diff --check` | ✅ ESEGUITO | PASS dopo aggiornamenti finali. |

### Dati Supabase

Creati: nessuno.  
Modificati: nessuno.  
Eliminati: nessuno.  
Cleanup richiesto: nessuno per questa execution.

### Rischi rimasti

- Consenso file-specifico e backup/rollback non disponibili.
- Nessun Excel reale small/large importato.
- Nessuna sentinella reale selezionata.
- Owner/sessione live iOS+Android non verificata end-to-end.
- Round-trip reali iOS→Supabase→Android e Android→Supabase→iOS non eseguiti.
- Scanner hardware/fallback, export reale, offline/retry reale e user acceptance finale non eseguiti.
- Supabase CLI linked read instabile dopo una prima query read-only riuscita.

### Aggiornamenti file di tracking

`docs/MASTER-PLAN.md` e questo file task sono stati aggiornati a **TASK-104 ACTIVE / REVIEW**, **Claude / Reviewer**, **READY FOR REVIEW**, **NON DONE**, verdict proposto **PARTIAL**. **TASK-105 non aperto**. Nessun claim **production-ready**, **production no-notes** o **100% globale** dichiarato.

---

## 26. Execution Pass 2 — Codex

### Avvio pass 2 — 2026-05-12 21:48 -0400

**Obiettivo compreso:** completare i gap del primo pass usando dati realistici sintetici quando dati reali negozio non sono disponibili o non sono sicuri. Il verdict finale dovrà distinguere chiaramente **realistic shop acceptance** da **real user data acceptance**.

**Run prefix:** `TASK104_PASS2_20260512_214804_`

**Gate autorizzati dall'utente in questo pass:**

- Creazione fixture Excel synthetic small/large privacy-safe.
- Creazione/modifica/eliminazione dati Supabase test scoped con prefisso run.
- Sentinelle `SENTINEL-A…E`.
- Build/test/smoke iOS e Android.
- Fix Swift/Kotlin/client-side solo se necessario e documentato.

**Vincoli confermati:** nessun dato reale non autorizzato, nessun service_role client, nessun bypass RLS, nessun cleanup distruttivo non scoped, nessun TASK-105, nessun claim production-ready globale.

### File da aggiornare

| Path | Motivo |
|------|--------|
| `docs/MASTER-PLAN.md` | Tracking temporaneo EXECUTION PASS 2 e handoff finale. |
| `docs/TASKS/TASK-104-real-shop-acceptance-ios-supabase-android.md` | Log pass 2 e handoff finale. |
| `docs/TASKS/EVIDENCE/TASK-104/*.md` | Aggiornare ledger/evidenze dal pass 1 a pass 2. |
| Eventuali fixture sintetiche privacy-safe | Solo se utili e giustificate; large preferibilmente temporaneo o generato. |

### Piano minimo pass 2

1. Generare fixture realistiche small/large e sentinelle synthetic.
2. Eseguire import/export/pre-generate/history dove verificabile con harness o app.
3. Eseguire Supabase scoped write/read-back senza service_role client e cleanup scoped.
4. Validare iOS/Android build/test/smoke e parità ProductPrice.
5. Aggiornare evidence pack, privacy scan e handoff finale verso REVIEW.

### Chiusura pass 2 — 2026-05-12 22:10 -0400

**Esito:** **READY FOR REVIEW** — verdict proposto **PASS_WITH_NOTES** nel solo perimetro **TASK-104 realistic shop acceptance**. Questo pass non è **real user data acceptance** perché non sono stati usati file/dati reali del negozio.

**Dataset / run:**

| Voce | Esito |
|------|-------|
| Run prefix | `TASK104_PASS2_20260512_214804_` |
| Small dataset | 50 prodotti sintetici; import/push/read-back iOS live e pull Android PASS. |
| Large dataset | 6.000 prodotti, 240 fornitori, 160 categorie, 24.000 `ProductPrice`; benchmark import/export/ProductPrice PASS. |
| Sentinelle | `SENTINEL-A` ... `SENTINEL-E`, privacy-safe e prefissate dal run. |
| Supabase rows finali | 10 suppliers, 10 categories, 55 products, 114 product prices, 0 duplicate active barcodes. |
| Cleanup | Righe synthetic scoped trattenute intenzionalmente per review; nessuna eliminazione eseguita. |

**Flussi completati:**

| Flusso | Stato | Evidenza |
|--------|-------|----------|
| Consenso/privacy | PASS | Autorizzazione utente a synthetic realistic data e write/read-back scoped registrata. |
| iOS auth/session/live | PASS | Auth preflight, collision scan, write/read-back, medium import/export, conflict/offline e residue scan PASS su device fisico. |
| Android auth/session/live | PASS | Primo preflight signed-out correttamente fallito; dopo sign-in UI Google, auth preflight e live instrumentation PASS su device fisico. |
| ProductPrice current/previous | PASS | Verificato live e su large synthetic. |
| iOS -> Supabase -> Android | PASS | Single-writer: pre-read, mutate iOS, push/read-back, pull/read Android, post-check. |
| Android -> Supabase -> iOS | PASS | Single-writer: mutate Android, push/read-back, pull/read iOS, post-check. |
| Export/share | PASS_WITH_NOTES | Export/re-read synthetic PASS; share destination manuale non confermata da operatore. |
| Offline/retry | PASS | Failed-before-write, retry, no duplicate, no-op post-check PASS. |
| Scanner/fallback | PASS_WITH_NOTES | Scanner hardware non testato; fallback manuale documentato come accettabile nel perimetro PASS2. |
| User acceptance | PASS_WITH_NOTES | Autorizzazione execution presente; accettazione finale operatore in persona non disponibile. |

**Codice modificato e perché:**

- `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`: harness live-gated esteso a prefisso/env TASK-104 PASS2 e aggiunto residue scan read-only scoped.
- `iOSMerchandiseControlTests/SupabaseConfigSecurityTests.swift`: auth preflight test-only esteso a gate TASK-104 PASS2.
- Android `Task103CrossPlatformAcceptanceTest.kt`: instrumentation test-only estesa a prefisso/gate TASK-104 PASS2.
- Android `Task103AuthPreflightTest.kt`: auth preflight instrumentation test-only estesa a gate TASK-104 PASS2.
- Nessun codice production Swift/Kotlin, schema, RLS, migration o backend modificato.

**Check eseguiti:**

| Check | Stato | Esito |
|-------|-------|-------|
| Build iOS Debug / build-for-testing fisico | ✅ ESEGUITO | PASS. |
| Build iOS Release simulator | ✅ ESEGUITO | PASS. |
| iOS XCTest live mirati | ✅ ESEGUITO | Auth preflight, collision, iOS write/read-back, medium import/export, conflict/stale, offline/retry, Android pull, residue scan: PASS. |
| iOS large synthetic benchmark | ✅ ESEGUITO | 3 test PASS: import/export/ProductPrice large. |
| iOS simulator smoke | ✅ ESEGUITO | Install/launch PASS. |
| Android assemble/install | ✅ ESEGUITO | `assembleDebug`, `assembleDebugAndroidTest`, install debug/test PASS. |
| Android instrumentation live mirata | ✅ ESEGUITO | Auth preflight dopo sign-in, pull iOS, Android write/read-back, pull medium: PASS. |
| Android broad unit suite | ⚠️ NON ESEGUIBILE come gate verde locale | Fallisce per ByteBuddy/attach JVM legacy nel runner locale; non è stato usato come PASS. Targeted build/instrumentation live PASS. |
| Supabase scoped read/write/read-back | ✅ ESEGUITO | PASS con client autenticati; no service role client, no RLS bypass. |
| `git diff --check` | ✅ ESEGUITO | PASS iOS e Android dopo patch finali. |
| Privacy scan evidence | ✅ ESEGUITO | PASS; nessun Excel/export/screenshot reale o segreto aggiunto al repo/evidence. |

**Rischi residui / note:**

- Mancano dati/file reali del negozio: verdict limitato a realistic shop acceptance.
- Scanner hardware camera non validato; solo fallback manuale.
- Share target manuale e file provider reale non confermati da operatore.
- User acceptance finale in persona non disponibile.
- Le righe Supabase synthetic scoped restano intenzionalmente per reviewer reproducibility; cleanup futuro deve essere prefix-scoped.
- Android full unit locale resta rumoroso per problema ByteBuddy/attach fuori perimetro TASK-104.

### Handoff post-execution pass 2

| Voce | Valore |
|------|--------|
| **Prossima fase** | **REVIEW** |
| **Prossimo agente** | **Claude / Reviewer** |
| **Handoff** | **READY FOR REVIEW** |
| **Verdict proposto** | **PASS_WITH_NOTES** |
| **Stato task** | **ACTIVE**, **NON DONE** |
| **TASK-105** | **Non aperto** |
| **Claim vietati** | Nessun **production-ready** globale, nessun **production no-notes**, nessun **100% globale**. |

## 22. Review finale Codex — 2026-05-12 22:35 -0400

**Obiettivo review compreso:** review indipendente completa di TASK-104 dopo Execution Pass 2, senza assumere vero il report execution, con correzione diretta di problemi reali e chiusura solo se il perimetro **realistic shop acceptance** risultava dimostrato.

**Problemi trovati:**

- Alcuni evidence file conservavano `Status: PARTIAL/BLOCKED` o wording Pass 1 non storicizzato, creando ambiguità rispetto al verdict PASS2.
- Harness iOS/Android usava log label ancora `TASK103_*` in vari punti anche quando il prefisso era `TASK104_PASS2_*`.
- I gate live accettavano solo `true` in alcuni test, mentre altri workflow documentavano anche `1`.
- Gli scan config controllavano `service_role`/`secret_key` ma non `sb_secret`.
- Il residue scan iOS TASK-104 PASS2 non assertava ancora i conteggi finali dichiarati.

**Fix applicati in review:**

- Rafforzati i test iOS in `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift` e `iOSMerchandiseControlTests/SupabaseConfigSecurityTests.swift`.
- Rafforzati i test Android in `Task103CrossPlatformAcceptanceTest.kt` e `Task103AuthPreflightTest.kt`.
- Riallineati status e wording evidence TASK-104 per separare chiaramente Pass 1 storico da Pass 2 e Review finale.
- Nessun codice production Swift/Kotlin, schema Supabase, RLS, migration o backend modificato.

**Check review eseguiti:**

| Check | Stato | Evidenza |
|-------|-------|----------|
| iOS Release simulator build | ✅ ESEGUITO | `xcodebuild ... -configuration Release ... build CODE_SIGNING_ALLOWED=NO` PASS. |
| iOS Release simulator install/launch | ✅ ESEGUITO | `simctl install` + `simctl launch` PASS, bundle `com.niwcyber.iOSMerchandiseControl`. |
| iOS targeted security/TASK-104/ProductPrice tests | ✅ ESEGUITO | XCTest mirati PASS; live TASK-104 tests skipped dove correttamente live-gated senza env/sessione review. |
| iOS large synthetic benchmark D100-L | ✅ ESEGUITO | `testS100C...Large...` PASS 15.905s; `testS100F...Large...` PASS 23.442s con sentinel `/tmp/TASK100_D100L` temporaneo poi rimosso. |
| Android assemble | ✅ ESEGUITO | `:app:assembleDebug :app:assembleDebugAndroidTest` PASS. |
| Android targeted unit/import/export tests | ✅ ESEGUITO | Targeted `testDebugUnitTest --tests ...` PASS. |
| Android auth preflight instrumentation | ✅ ESEGUITO | `connectedDebugAndroidTest` su device IN2013 PASS con `task104Pass2AuthPreflight=true`. |
| Android broad unit suite | ✅ ESEGUITO — NOT GREEN | `:app:testDebugUnitTest` fallisce 137 test per ByteBuddy/attach; non usato come PASS né mascherato. |
| Supabase cleanup | ⚠️ NON ESEGUITO | Decisione review: trattenere righe synthetic scoped per reproducibility; cleanup futuro solo prefix-scoped. |
| Supabase live write/read-back rerun | ⚠️ NON ESEGUITO | Non rieseguito in review per evitare nuove mutazioni; evidence PASS2 e harness rafforzato verificano il percorso scoped. |
| Privacy/security scan finale | ✅ ESEGUITO | Evidence/diff scan PASS; `service_role` solo come policy text, nessun `sb_secret`, token, email, path personale o artifact reale aggiunto. |
| `git diff --check` | ✅ ESEGUITO | PASS iOS e Android dopo patch finali. |

**Decisione cleanup/retention Supabase:** mantenere intenzionalmente i dati sintetici scoped `TASK104_PASS2_20260512_214804_` per reproducibility della review. Conteggi accettati nel verdict: 10 suppliers, 10 categories, 55 products, 114 product prices, 0 duplicate active barcodes. Nessun cleanup distruttivo non scoped.

**Verdict finale:** **TASK-104 DONE / Chiusura — REVIEW PASS FINAL / PASS_WITH_NOTES** per **realistic shop acceptance** con dati sintetici privacy-safe. Non è **real user data acceptance**, non è **production-ready globale**, non è **production no-notes**, non è **100% globale**. **TASK-105 resta TODO / Planning — non aperto**.
