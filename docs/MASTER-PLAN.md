# Master Plan — iOSMerchandiseControl

## Progetto
iOSMerchandiseControl — app iOS per controllo merce e inventario

## Obiettivo attuale
Nessun task attivo. **TASK-040** *Supabase full pull + remote identity bridge SwiftData allineato Android/Supabase* è **DONE / Chiusura** con review **APPROVED_FIXED_DIRECTLY**: fix diretto mirato su conflitti `remoteID` lookup supplier/category, build Debug PASS, build Release PASS, XCTest completo PASS, localizzazioni/anti-scope PASS; nessuna scrittura Supabase, nessun push, nessun sync automatico. **TASK-039** resta **DONE / Chiusura** (non riaperto). **TASK-038** resta **DONE / Chiusura**. **TASK-034**, **TASK-035**, **TASK-037**, **TASK-036** restano **DONE**. **TASK-032** resta **BLOCKED / on hold**; **TASK-028** resta **BLOCKED**.

## Stato globale
IDLE
> **2026-04-27 (user override):** **TASK-031** promosso ad **ACTIVE / EXECUTION** con responsabile operativo **Cursor/Codex executor**. Planning approvato; perimetro limitato a import/header recognition in `ExcelAnalyzer`, senza Supabase, senza `RowDetailSheetView`, senza redesign PreGenerate.
> **2026-04-27 (handoff):** execution TASK-031 completata da **Cursor/Codex** con build Debug Simulator PASS e fixture documentali A-F sotto `docs/fixtures/TASK-031/`; handoff a **CLAUDE / REVIEW**. Nessun Supabase / nessun `RowDetailSheetView` / nessun redesign PreGenerate.
> **2026-04-27 (review/close):** **TASK-031** review tecnica completata da **Claude Code reviewer/fixer** con esito **APPROVED_FIXED_DIRECTLY**: fix diretto limitato a commento `ColumnStatus.normalized` e soglia più conservativa per header scoring; build Debug Simulator PASS; task chiuso **DONE** su autorizzazione utente esplicita.
> **2026-04-27 (user override):** **TASK-036** promosso ad **ACTIVE / EXECUTION** con responsabile operativo **Cursor/Codex executor**. Nota: l'utente ha proposto `TASK-032`, ma `TASK-032` esiste gia' per un task GeneratedView; per coerenza ID/path viene usato il follow-up gia' presente `TASK-036`. TASK-031 resta DONE e non viene riaperta.
> **2026-04-27 (handoff):** execution TASK-036 completata da **Cursor/Codex** con build Debug Simulator PASS e fixture documentali sotto `docs/fixtures/TASK-036/`; handoff a **CLAUDE / REVIEW**. Nessun Supabase / nessun `RowDetailSheetView` / nessun redesign PreGenerate.
> **2026-04-27 (review/close):** **TASK-036** review tecnica completata da **Claude Code reviewer/fixer** con esito **APPROVED_FIXED_DIRECTLY**: fix diretto limitato a righe dirette table/section, scoring piu' conservativo decorative-only, fixture rafforzate e assegnazione per indice logico; build Debug Simulator PASS; task chiuso **DONE** su autorizzazione utente esplicita.
> **2026-05-04 (planning/tracking/user override):** **TASK-037** ripreso in **ACTIVE / PLANNING** per **slice 2** (solo perfezionamento planning: matrice XCTest estesa 1–8, fixture reali/minimali, append/multi-file, microcopy UX documentata, strategia execution futura). **Nessuna execution Swift** e nessuna modifica a `project.pbxproj` in questo turno. **TASK-036** resta **DONE**. La **slice 1** TASK-037 (target + 5 test, `2026-04-27`) resta archiviata nel file task come chiusura DONE storica. **Review documentale** piano slice 2: **APPROVED** (vedi file task); prossimo passo: **READY FOR REVIEW APPROVAL** / conferma utente → **EXECUTION** solo con **user override** esplicito; slice 2 **non** DONE automatico.
> **2026-05-04 (execution/user override):** utente ha autorizzato esplicitamente il passaggio di **TASK-037 slice 2** da **PLANNING / READY FOR REVIEW APPROVAL** a **ACTIVE / EXECUTION**. Responsabile operativo **Cursor/Codex executor**; perimetro limitato a test XCTest parser-only, fixture TASK-036 docs/test, tracking, e solo eventuale micro-helper puro in `ExcelSessionViewModel.swift` se indispensabile. **TASK-036** resta **DONE** e non viene riaperto.
> **2026-05-04 (handoff):** execution **TASK-037 slice 2** completata da **Cursor/Codex**: aggiunti test XCTest parser-only P0/P1/P2, fixture duplicate docs/bundle test allineate, README fixture aggiornato; build Debug Simulator PASS e `xcodebuild test` PASS su iPhone 16e iOS 26.2. Handoff a **Claude / REVIEW**. Nessun `project.pbxproj`, scheme, UI runtime, Supabase o Swift production modificato; **TASK-036** resta **DONE**.
> **2026-05-04 (review/close/user override):** **TASK-037 slice 2** review tecnica completata da **Codex reviewer/fixer** su override esplicito: nessun problema bloccante, nessun fix test/fixture necessario, `project.pbxproj` senza diff, fixture docs/test allineate, build Debug Simulator PASS e `xcodebuild test` PASS su iPhone 16e iOS 26.2 con 9/9 test HTML parser passati. Task chiuso **DONE / Chiusura**; **TASK-036** resta **DONE** e non viene riaperto.
> **2026-04-27 (user override):** **TASK-037** creato e promosso ad **ACTIVE / EXECUTION** con responsabile operativo **Cursor/Codex executor** per aggiungere un target XCTest minimale coerente col perimetro TASK-036. TASK-031 e TASK-036 restano DONE e non vengono riaperti.
> **2026-04-27 (handoff):** execution TASK-037 completata da **Cursor/Codex**: target `iOSMerchandiseControlTests`, scheme condiviso, fixture TASK-036 nel bundle test e suite `ExcelAnalyzerHTMLParsingTests`; `xcodebuild test` PASS su iPhone 16e Simulator; handoff a **CLAUDE / REVIEW**.
> **2026-04-27 (review/close):** **TASK-037** review tecnica completata da **Claude Code reviewer/fixer** con esito **APPROVED_FIXED_DIRECTLY**: fix diretto limitato a README fixture e rafforzamento multi-table con tabella decorativa post-dati; build Debug Simulator PASS; test XCTest PASS 5/5; task chiuso **DONE** su autorizzazione utente esplicita.
> **2026-04-27 (planning/tracking):** **TASK-032** promosso da backlog **TODO** ad **ACTIVE** in fase **PLANNING**; responsabile **planner (CLAUDE/Cursor planning)**; obiettivo: completare planning operativo per validazione residua **TASK-028** (multi-riga, iPhone grande, dati mancanti/ambigui) **senza** riaprire TASK-028 come task di implementazione. In quel momento l’Execution era rimandata a successivo OK utente. **TASK-031**, **TASK-036**, **TASK-037** restano **DONE**.
> **2026-04-27 (execution/user override):** ~~**TASK-032** passa da **PLANNING** a **EXECUTION**~~ — **annullato per tracking**: restava documentazione inconsistente (evidenze EXECUTION senza fase reale concordata).
> **2026-04-28 (planning/tracking):** **TASK-032** riallineato ad **ACTIVE / PLANNING**; responsabile **Planner**; fase pre-Execution in attesa di avvio formale; **TASK-028** resta **BLOCKED** (**non** DONE). Nessun altro task modificato.
> **2026-04-28 (execution start/user override):** **TASK-032** passa formalmente ad **ACTIVE / EXECUTION**; responsabile **Cursor / Execution**. Avvio limitato a validazione controllata + preparazione evidenze **P0→P5**; **nessun** fix codice, redesign o refactor generale autorizzato da questa transizione; **TASK-028** resta **BLOCKED** (**non** DONE).
> **2026-04-27 (user override):** **TASK-030** promosso ad **ACTIVE / EXECUTION** con responsabile operativo **CURSOR**. Obiettivo: finalizzare il flusso full-database import/export multi-sheet prima di Supabase, con validazione reimport idempotente, diff non-product e progress/cancellation UX.
> **2026-04-27 (handoff):** execution reale TASK-030 eseguita da **CURSOR** con build verde, probe runtime parziale, fix minimo UX no-work e handoff a **CLAUDE / REVIEW**. Matrice runtime M-1…M-10 non chiusa per fixture temporanee non valide come evidenza deterministica.
> **2026-04-27 (review):** **TASK-030** review tecnica completata da **CLAUDE CODE** con esito **CHANGES_REQUIRED_FIXED_DIRECTLY**: fix diretto limitato a guardia UX no-work; build PASS; task **non DONE** e **BLOCKED** in attesa di runtime validation canonica o accettazione esplicita del gap.
> **2026-04-26 (review):** **TASK-029** completato come audit documentale/tracking-only. Matrice, tassonomia, test pack A–E e raccomandazione prossima **TASK-030** approvate. Nessun codice Swift/Supabase modificato.
> **User override 2026-04-26 (invariato per TASK-028):** **TASK-028** sospeso in **BLOCKED** dopo validazione runtime/visiva read-only positiva ma incompleta. Build PASS, iPhone piccolo light/dark PASS, complete/incomplete PASS, campi secondari PASS sul caso completo. Nessuna regressione TASK-028 rilevata e nessun FIX richiesto. Test residui rinviati: iPhone grande row detail, prev/next multi-riga, scanner reopen dopo permesso camera, caso dati mancanti/ambigui.
> **2026-05-03 (review/user override):** **TASK-032** slice **FIX D2** review completata con esito **APPROVED D2 slice / accepted**. Nessun fix Swift in Review; build simulator PASS; runtime non ripetuto perche' il flow D2 non e' stato modificato dopo le evidenze Execution. **TASK-032 non DONE**: prossima slice **P2–P5/scanner** pending. **TASK-028 resta BLOCKED**.
> **2026-05-03 (execution+fix/user override):** utente ha chiesto di “eseguire tutto per farlo in DONE”. Codex ha validato **P2–P4 PASS runtime**, trovato **P5 scanner reopen FAIL / non verificato PASS**, applicato micro-fix in `GeneratedView.swift` e ribuildato; runtime non ha prodotto evidenza stabile di reopen. **TASK-032 non DONE**; **TASK-028 resta BLOCKED**.
> **2026-05-03 (tracking/user override):** utente ha chiesto di mettere **TASK-032** in pausa e attivare **TASK-033**. **TASK-032** passa a **BLOCKED / on hold**; non e' DONE perche' **P5 scanner reopen** resta senza PASS. **TASK-033** passa da **TODO** ad **ACTIVE / PLANNING**. **TASK-028 resta BLOCKED**.
> **2026-05-03 (review/close):** **TASK-033** review documentale completata con esito **APPROVED**: audit Supabase/iOS/Android verificato, micro-correzione follow-up per evitare collisione con **TASK-036/TASK-037** già assegnati, nessun codice Swift/Kotlin/SQL modificato, build iOS PASS. Task chiuso **DONE** su autorizzazione utente esplicita; **TASK-034** sbloccata come next candidate ma non attivata.
> **2026-05-03 (execution/user override):** utente ha autorizzato esplicitamente l'**EXECUTION** di **TASK-034**. Codex ha letto integralmente il task e aggiornato la metadata del task a **ACTIVE / EXECUTION** con responsabile **CODEX**; perimetro invariato: foundation Supabase iOS read-only, nessun push, nessun sync automatico, nessuna auth/login/JWT manuale.
> **2026-05-03 (handoff):** execution TASK-034 completata da Codex: Supabase Swift SPM `2.46.0`, config plist sicura, DTO readonly, service read-only, diagnostica DEBUG localizzata; build Debug Simulator PASS; catalog probe live non eseguito per assenza di `SupabaseConfig.plist` reale (`configMissing` documentato). Handoff a **CLAUDE / REVIEW**.
> **2026-05-04 (review/close/user override):** **TASK-034** review tecnica completata con esito **APPROVED** e micro-fix diretto di sicurezza/localizzazione diagnostica; build Simulator PASS, build quiet PASS, `git diff --check` PASS; nessun segreto, nessuna scrittura remota/locale, nessun auth/login/sync. Task chiuso **DONE** su override esplicito dell'utente. **TASK-035** sbloccata come **next candidate**, non attivata.
> **2026-05-04 (execution/user override):** utente ha autorizzato esplicitamente l'**EXECUTION** di **TASK-035**. Codex ha letto task/planning/fonti richieste e aggiornato metadata a **ACTIVE / EXECUTION** con responsabile **Cursor/Codex**; perimetro invariato: preview dry-run Supabase → SwiftData, nessuna scrittura locale/remota, nessun apply/merge/backfill/sync reale.
> **2026-05-04 (handoff):** execution TASK-035 completata da **Cursor/Codex**: modelli preview/snapshot Sendable, snapshot SwiftData read-only, fetch Supabase paginato read-only, diff engine conservativo, UI DEBUG localizzata, test XCTest puri PASS; build quiet PASS; nessuna scrittura locale/remota, nessun apply/merge/backfill/sync reale. Handoff a **CLAUDE / REVIEW**.
> **2026-05-04 (review/close/user override):** **TASK-035** review tecnica completata con esito **APPROVED / DONE**. Fix diretti piccoli: budget paginazione rispettato sotto page size, test puri aggiunti per barcode remoto vuoto e ProductPrice preview-only, label preview localizzate rifinite. Build Debug PASS, Build Release PASS, XCTest PASS su iPhone 16e iOS 26.1; anti-scrittura locale/remota PASS; localizzazioni e `git diff --check` PASS; nessun segreto/config reale tracciato. Task chiuso **DONE** su override esplicito dell'utente.
> **2026-05-04 (planning/tracking/user override):** creato **TASK-038** *Supabase Google Auth foundation iOS*; promosso ad **ACTIVE / PLANNING** con responsabile **Planner / Cursor**. Solo `docs/TASKS/TASK-038-supabase-google-auth-foundation-ios.md` + **`MASTER-PLAN`**; **nessuna execution Swift**, nessuna modifica `project.pbxproj` / `Info.plist` / sorgenti. **TASK-034** e **TASK-035** restano **DONE**. Prossimo candidate: **TASK-039** — preview → apply locale controllato SwiftData (file task futuro).
> **2026-05-04 (planning refinement):** **TASK-038** — client condiviso session-aware + **DI**, **state machine**, **OAuth**/`handle(url)` ufficiali pinata + **listener** sessione, **checklist esterna**, **Section** `OptionsView`, **CA**. *(Matrice estesa a **T-1…T-12** nel planning finalizzato successivo.)*
> **2026-05-04 (planning finalizzato — TASK-038):** integrato nel file task: **preview cloud auth-gated** (**nessun** fallback anon post-TASK-038), **diagnostica read-only post-login**, divieto **SDK Google/Firebase** extra salvo blocker documentato, listener **`authStateChanges`**, matrice **T-1…T-12**, **TASK-039** candidato **invariato**. Solo markdown/tracking; **PLANNING**; nessun Swift/plist/pbxproj/Package.resolved.
> **2026-05-05 (execution/user override):** **TASK-038** portato ad **ACTIVE / EXECUTION** con responsabile **Cursor/Codex executor**. Nota: implementazione auth Google Supabase foundation; nessun apply SwiftData, nessun push remoto.
> **2026-05-05 (handoff):** execution **TASK-038** completata da **Cursor/Codex**: client Supabase condiviso session-aware, Google OAuth Supabase Auth via API ufficiali pinata, state machine auth, `OptionsView` DEBUG auth-gated, preview/diagnostica senza fallback anon, localizzazioni e URL scheme. Build Debug PASS, Build Release PASS, XCTest PASS 18/18. Handoff a **Claude / REVIEW**. Nessun apply SwiftData, nessun push remoto, nessun SDK Google/Firebase extra.
> **2026-05-05 (review/close/user override):** **TASK-038** review tecnica completata da **Codex reviewer/fixer** con esito **APPROVED_FIXED_DIRECTLY**: fix diretto limitato a hardening `SupabaseConfig` per rifiutare legacy `service_role` JWT, test XCTest dedicato e microcopy header localizzato; build Debug PASS, build Release PASS, XCTest PASS 19/19, localizzazioni/plist/git diff check PASS, anti-segreti/anti-scrittura PASS. Task chiuso **DONE / Chiusura** su autorizzazione esplicita utente. **TASK-039** resta next candidate, non attivo.
> **2026-05-05 (review finale post-test live/user override):** **TASK-038** confermato **DONE / Chiusura** con esito **APPROVED_FIXED_DIRECTLY** dopo evidenza live utente: Google login iOS PASS, redirect custom scheme PASS, UI ZH-Hans mostra account connesso, dry-run Supabase auth-gated PASS con preview parziale coerente col cap `10_000`. Fix diretto aggiuntivo: opt-in `emitLocalSessionAsInitialSession: true` per Supabase Swift 2.46.0 e guardia `session.isExpired` nello stato auth/UI. `SupabaseConfig.plist` reale presente solo localmente e ignorato da git; nessun riferimento a plist reale in `project.pbxproj`; build Debug/Release PASS, XCTest PASS 19/19, plutil/git diff/check sicurezza PASS. **TASK-039** resta candidate, non attivo; dovrà bloccare apply su preview partial o implementare fetch completo/paginazione controllata.

> **2026-05-05 (planning/tracking/user override):** creato file task **TASK-039** *Supabase preview → apply locale controllato SwiftData*; promosso ad **ACTIVE / PLANNING** con responsabile **Claude / Planner**; **solo planning** — **nessuna execution Swift**, **nessun push remoto**. **Stato globale progetto:** **ACTIVE**. **TASK-038** resta **DONE**.
> **2026-05-05 (execution/user override):** utente ha autorizzato esplicitamente l'**EXECUTION** di **TASK-039**. Responsabile operativo **Cursor / Executor**; perimetro invariato: apply solo locale SwiftData da preview completa/sicura, nessuna scrittura Supabase, nessun push, nessun sync automatico/background/realtime, nessun delete locale da tombstone.
> **2026-05-05 (handoff):** execution **TASK-039** completata da **Cursor / Executor**: payload applicabile preview, `SupabasePullApplyService` no-network con `prepareApplyPlan` puro e `apply(plan:)` locale SwiftData, guardrail partial/sourceErrors/priceHistory/conflicts/stale, UI DEBUG con conferma e copy safe, localizzazioni IT/EN/ZH-Hans, XCTest apply in-memory. Build Debug PASS, Build Release PASS, XCTest PASS 37/37, `git diff --check` PASS. Handoff a **Claude / Reviewer**. Nessuna scrittura Supabase, nessun delete da tombstone, nessun `ProductPrice` remoto, nessun push.
> **2026-05-05 (review/close/user override):** **TASK-039** review tecnica completata da **Claude / Reviewer+Fixer** con esito **APPROVED_FIXED_DIRECTLY / DONE**: fix diretto limitato a conflitti lookup remoti mancanti per nuovi prodotti e localizzazione ES delle nuove chiavi apply; build Debug PASS, build Release PASS, XCTest PASS 38/38, `git diff --check` PASS, localizzazioni OK, anti-scrittura Supabase PASS, anti-`ProductPrice` apply PASS. Task chiuso **DONE / Chiusura** su istruzione esplicita dell'utente. **TASK-038** resta **DONE**.
> **Nota corrente:** nessun task attivo; **TASK-040** **DONE / Chiusura** con esito **APPROVED_FIXED_DIRECTLY**. **TASK-039** **DONE / Chiusura** (non riaperto). **TASK-038** **DONE / Chiusura**. **TASK-037** **DONE / Chiusura** anche per slice 2. **TASK-035** **DONE / Chiusura**. **TASK-034** **DONE / Chiusura**. **TASK-032** in pausa **BLOCKED / on hold**. **TASK-028** — **BLOCKED**.

> **2026-05-05 (planning/tracking):** creato **TASK-040** *Supabase full pull + remote identity bridge SwiftData allineato Android/Supabase*; promosso ad **ACTIVE / PLANNING** con responsabile **Claude / Planner**; **solo** `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md` + **`MASTER-PLAN`** — **nessuna modifica Swift**, **nessun** `project.pbxproj` / `Info.plist` / `Package.resolved` / SQL. **TASK-039** resta **DONE** e **non** viene riaperto. Riferimenti Android: TASK-067 **DONE ACCEPTABLE**, TASK-068 **PARTIAL**, TASK-069/070/071 **DONE**.

> **Planning refinement (TASK-040):** pre-execution gates; embedded metadata vs ref tables; policy `remoteID`; idempotenza; performance ~20k; date/TZ + privacy log; struttura Sezioni Options; CA-18–CA-25; fase **PLANNING** invariata; **nessuna** execution Swift; **nessuna** scrittura Supabase; **TASK-039** **DONE**.
> **2026-05-05 (execution/user override Slice A):** **TASK-040** portato ad **ACTIVE / EXECUTION** con responsabile **Cursor / Executor**. Scope limitato a **Slice A**: remote identity metadata SwiftData embedded su Product/Supplier/ProductCategory + XCTest in-memory; **no Supabase writes; no push; no pull/apply behavior changes; TASK-039 remains DONE**.
> **2026-05-05 (handoff):** execution **TASK-040 Slice A/B/C/D** completata da **Cursor / Executor**: full pull preview con paginazione deterministica/budget partial, bridge `remoteID` SwiftData Product/Supplier/Category, link/apply locale idempotente con conflitti `remoteIdConflict`/`missingRemoteReference`, UI DEBUG Options localizzata. Build Debug PASS, Build Release PASS, XCTest PASS, `git diff --check` PASS, grep anti-scope PASS. Handoff a **Claude / Reviewer**. **Nessuna scrittura Supabase**, **nessun push**, **nessun sync automatico**, **nessun `record_sync_event`**, **nessun dirty/outbox**, **nessun ProductPrice apply remoto**. **TASK-039 resta DONE**.
> **2026-05-05 (review/close/user override):** **TASK-040** review tecnica completa eseguita da **Codex / Reviewer+Fixer** con esito **APPROVED_FIXED_DIRECTLY / DONE**: fix diretto limitato a conflitti `remoteID` per duplicati locali e supplier/category omonimi con UUID remoto diverso, piu' hardening apply anti-merge silenzioso. Build Debug PASS, build Release PASS, XCTest completo PASS, `git diff --check` PASS, localizzazioni PASS, anti-scope PASS. Nessuna scrittura Supabase, nessun push, nessun `record_sync_event`, nessun outbox/dirty, nessun ProductPrice apply remoto, nessun SQL/migration. **TASK-039 resta DONE**. Follow-up futuri registrati ma non attivati.

## Workflow task attivo
- **Task attivo:** Nessuno
- **Titolo:** N/A
- **File task:** N/A
- **Stato task:** N/A
- **Fase:** N/A
- **Responsabile:** N/A
- **Ultimo aggiornamento:** 2026-05-05
- **Nota tracking:** TASK-040 chiuso DONE / Chiusura con esito APPROVED_FIXED_DIRECTLY; progetto IDLE; TASK-039 resta DONE.

## Fonti di verità
- Questo file = vista globale, backlog, task attivo, avanzamento generale
- File task attivo = dettaglio operativo, fase corrente, handoff, stato del lavoro
- Se divergono: il file task attivo prevale come riferimento operativo; riallineare questo file di conseguenza

## Regole operative
- Un solo task attivo per volta
- Il task attivo è l'unica unità di lavoro corrente
- **Stato globale progetto**: IDLE (nessun task attivo) | ACTIVE (un task in lavorazione)
- **Stato task**: TODO (nel backlog) | ACTIVE (in lavorazione) | BLOCKED (sospeso) | DONE (completato)
- **Fase task** (solo per ACTIVE): PLANNING | EXECUTION | REVIEW | FIX
- "Responsabile attuale" = chi deve agire ORA (coerente con la fase)
- Criteri di accettazione = contratto del task (definiti in planning, usati in execution e review)
- Il campo `File task` deve sempre corrispondere al file reale nel filesystem — mismatch = incoerenza bloccante
- Task interrotto senza completamento → BLOCKED con motivazione oppure TODO nel backlog, mai lasciato in stato ambiguo
- MASTER-PLAN aggiornato solo se cambia: task attivo, fase, stato, blocchi, avanzamento reale
- Backlog e priorità aggiornabili solo da Claude o dall'utente, mai da Codex, sempre con motivazione esplicita
- Quando il progetto passa da IDLE ad ACTIVE, la sezione "Task attivo" deve essere compilata subito con tutti i campi obbligatori (ID, titolo, file task, stato, fase, responsabile, ultimo aggiornamento)

## Transizioni valide di fase
```
PLANNING → EXECUTION → REVIEW → FIX → REVIEW → ... → conferma utente → DONE
                                  ↓ (se REJECTED)
                               PLANNING
```
- PLANNING → EXECUTION (dopo handoff)
- EXECUTION → REVIEW (dopo handoff)
- REVIEW → FIX (se CHANGES_REQUIRED)
- FIX → REVIEW (sempre, loop obbligatorio)
- REVIEW → DONE (solo dopo conferma utente, se APPROVED)
- REVIEW → PLANNING (se REJECTED)
Qualunque altra transizione è invalida.

## Esiti della review
- **APPROVED** = criteri soddisfatti, nessun fix necessario → conferma utente → DONE
- **CHANGES_REQUIRED** = fix mirati necessari, task recuperabile → FIX
- **REJECTED** = fuori perimetro o incoerente, da rifare in modo sostanziale → nuovo PLANNING

## Task attivo
- **Nessun task attivo** — progetto **IDLE** dopo chiusura **TASK-040 DONE / Chiusura**.
- Ultimo task chiuso: **TASK-040** — `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md`
- Ultimo aggiornamento: **2026-05-05**
- Nota tracking: **APPROVED_FIXED_DIRECTLY / DONE**; nessuna scrittura Supabase; nessun push; nessun sync automatico; **TASK-039 resta DONE**.

Follow-up candidate post TASK-040 (**non attivi**):
- **TASK-041 candidato**: push manuale tombstone-compliant.
- Task futuro: ProductPrice remote apply / price sync.
- Task futuro: outbox/sync_events iOS.
- Task futuro: realtime/background sync.
- Task futuro: delete inbound da tombstone.
- Task futuro: validazione live su catalogo Supabase grande.

Follow-up storico post-AUTH (ex post TASK-035):
- Apply locale controllato dopo conferma utente → tracciato e completato come **TASK-039** (**DONE / Chiusura**).

Task bloccati non attivi:
- Task ID: TASK-032
- Titolo: GeneratedView multi-row navigation validation + missing-data scenarios
- File task: `docs/TASKS/TASK-032-generatedview-multi-row-navigation-validation-missing-data-scenarios.md`
- Stato: BLOCKED
- Motivo: user override 2026-05-03 — task messo in pausa dopo D2 accepted e P2–P4 PASS runtime. **P5 scanner reopen** resta senza evidenza PASS dopo tentativi di micro-fix; TASK-032 non DONE. Alla ripresa: ripartire dal gate P5/scanner reopen o da decisione formale di scope, poi review finale.
- Ultimo aggiornamento: 2026-05-03
- Task ID: TASK-030
- Titolo: Full-database import/export finalization: reimport idempotency + non-product diff + progress UX
- File task: `docs/TASKS/TASK-030-full-database-import-export-finalization-reimport-idempotency-non-product-diff-progress-ux.md`
- Stato: BLOCKED
- Motivo: Review tecnica 2026-04-27 — esito **CHANGES_REQUIRED_FIXED_DIRECTLY**. Fix diretto applicato alla guardia UX no-work; build Debug Simulator PASS; localizzazioni OK; nessun Supabase / nessuna nuova dipendenza. Task non DONE perché mancano evidenze runtime canoniche M-1…M-10 con workbook generato dall'export reale dell'app o equivalente.
- Ultimo aggiornamento: 2026-04-27
- Task ID: TASK-028
- Titolo: GeneratedView: Row Detail UX Refinement vs Android
- File task: `docs/TASKS/TASK-028-generatedview-row-detail-ux-refinement.md`
- Stato: BLOCKED
- Motivo: User override 2026-04-26 — validazione runtime/visiva read-only eseguita da Codex con esito positivo ma incompleto. Build PASS, iPhone piccolo light/dark PASS, complete/incomplete PASS, campi secondari PASS sul caso completo. Nessuna regressione TASK-028 rilevata e nessun FIX richiesto. Test residui sospesi: iPhone grande row detail, prev/next multi-riga, scanner reopen dopo decisione permesso camera, caso dati mancanti/ambigui. Task non DONE; pending manual validation finale.
- Ultimo aggiornamento: 2026-04-26
- Task ID: TASK-027
- Titolo: ManualEntrySheet: modalità «Aggiungi e continua» (rapid entry)
- File task: `docs/TASKS/TASK-027-manualentrysheet-aggiungi-e-prossimo.md`
- Stato: BLOCKED *(sospeso — **non** **DONE** definitivo)*
- Motivo: implementation **completata**; review **completata** con esito **OK** / **APPROVED**; **test manuali T-1…T-13 non eseguiti** — **motivo esplicito della sospensione:** validazione manuale mancante. **On hold for manual verification**. Alla ripresa: test manuali → eventuale **FIX** → **REVIEW** → conferma utente → **DONE**. Planning tecnico del file task **invariato**.
- Ultimo aggiornamento: 2026-03-26
- Task ID: TASK-026
- Titolo: Scanner: toggle torcia (flashlight)
- File task: `docs/TASKS/TASK-026-scanner-toggle-torcia-flashlight.md`
- Stato: BLOCKED
- Motivo: review **APPROVED** acquisita; **nessun fix** aperto dalla review; build Debug verde; **test manuali T-1…T-9 non ancora eseguiti**; task **non** DONE. **In sospensione / pending manual validation**. Alla ripresa: eseguire **T-1…T-9** manualmente prima della chiusura finale → eventuale **FIX** se regressioni → **REVIEW** → conferma utente → **DONE**.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-025
- Titolo: GeneratedView: ricalcolo dinamico paymentTotal + missingItems su History card
- File task: `docs/TASKS/TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`
- Stato: BLOCKED
- Motivo: review tecnica **APPROVED** gia' acquisita; **test manuali utente** (T-0..T-15) **non ancora eseguiti**; task **non** DONE. Congelata in attesa di futura validazione manuale. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** finale → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-021
- Titolo: HistoryEntry: warning su dati corrotti / deserializzazione fallita
- File task: `docs/TASKS/TASK-021-historyentry-warning-dati-corrotti-deserializzazione.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — sospeso temporaneamente per focus operativo su **TASK-025**; review post-fix **APPROVED** gia' acquisita; **non** DONE; in attesa **conferma finale utente** alla ripresa (eventuali test manuali T-5 / runtime T-1..T-3/T-7 restano rischi noti documentati nel file task).
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-020
- Titolo: Scanner: feedback camera non disponibile
- File task: `docs/TASKS/TASK-020-scanner-feedback-camera-non-disponibile.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — review **APPROVED**; **nessun fix richiesto**; test manuali **T-1..T-6 non eseguiti** in questo turno; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** solo se regressioni → **REVIEW** finale → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-019
- Titolo: Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill
- File task: `docs/TASKS/TASK-019-robustezza-guardie-generatedview-cascade-delete-async-backfill.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — execution **completata**; review tecnica **APPROVED**; **nessun fix richiesto**; **test manuali non eseguiti** in questo turno; task **non** DONE. Alla ripresa: test manuali (CA-2B/CA-3B store/delete, CA-2C dataset grande, smoke Fix A se opportuno) → eventuale **FIX** solo se emergono regressioni → **REVIEW** finale → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-018
- Titolo: GeneratedView: secondo livello revert (ai dati originali import)
- File task: `docs/TASKS/TASK-018-generatedview-second-level-revert.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — execution **completata**; review codice **APPROVED**; **nessun fix richiesto**; test manuali **CA-7** (**S-1**, **M-1..M-10**, **M-12**) **non ancora eseguiti**; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-017
- Titolo: PreGenerate: validazione esplicita colonne obbligatorie
- File task: `docs/TASKS/TASK-017-pregenerate-validazione-esplicita-colonne-obbligatorie.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-24** — implementazione (execution + fix) **completata**; review tecnica **APPROVED**; **test manuali utente (T-1..T-10) non eseguiti in questa fase**; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-016
- Titolo: Deduplicazione logica import DatabaseView/ProductImportViewModel
- File task: `docs/TASKS/TASK-016-deduplicazione-logica-import-databaseview-productimportviewmodel.md`
- Stato: BLOCKED
- Motivo: review **APPROVED** (Claude) e warning build/concurrency sistemati; **test manuali ancora pendenti/non eseguiti**; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** solo se emergono regressioni → **REVIEW** → conferma utente → DONE. Riprendibile dal punto corrente senza rifare planning da zero.
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-024
- Titolo: Full-database import progress UX + cancellation
- File task: `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`
- Stato: BLOCKED
- Motivo: sospeso temporaneamente per decisione utente; review/fix UI non portati a finalizzazione; nessun DONE. Alla ripresa si continua dal punto corrente (review/fix residuo) senza rifare planning da zero.
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-023
- Titolo: Full-database reimport idempotency + non-product diff visibility
- File task: `docs/TASKS/TASK-023-full-db-reimport-idempotency-and-non-product-diff-visibility.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-24** — sospeso temporaneamente; review codice APPROVED ma **test manuali solo parziali / non conclusi**; **non** DONE. Alla ripresa: test manuali residui + eventuale FIX + conferma utente (**nessun** nuovo planning da zero).
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-011
- Titolo: Large import stability, memory e progress UX
- File task: `docs/TASKS/TASK-011-large-import-stability-and-progress.md`
- Stato: SUPERSEDED
- Motivo: umbrella completamente superato da TASK-022 (DONE, crash fix), TASK-023 (reimport idempotency), TASK-024 (progress UX). Nessun lavoro residuo non coperto. Aggiornato da audit 2026-03-25.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-009
- Titolo: Product model old prices + price backfill
- File task: `docs/TASKS/TASK-009-product-model-old-prices-price-backfill.md`
- Stato: BLOCKED
- Motivo: implementazione completata e review codice APPROVED da Claude (2026-03-22); test manuali VM-1..VM-9 non ancora eseguiti; task sospeso per decisione utente in attesa di validazione manuale futura. Alla ripresa: eseguire VM-1..VM-9, poi confermare DONE o aprire FIX se emergono regressioni.
- Ultimo aggiornamento: 2026-03-22
- Task ID: TASK-013
- Titolo: sim_ui.sh performance — batch mode, timeout reale, cache device frame
- File task: `docs/TASKS/TASK-013-sim-ui-performance.md`
- Stato: WONT_DO
- Motivo: wrapper SIM UI rimosso dal workflow standard (2026-03-22); nessun ulteriore lavoro previsto. Aggiornato da BLOCKED a WONT_DO da audit 2026-03-25.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-005
- Titolo: ImportAnalysis error export + inline editing
- File task: `docs/TASKS/TASK-005-importanalysis-error-export-inline-editing.md`
- Stato: BLOCKED
- Motivo: implementazione completata da Codex e task gia` portato in review, ma la validazione manuale e` ancora incompleta; sospeso temporaneamente in attesa dei test manuali residui prima di emettere APPROVED o CHANGES_REQUIRED
- Ultimo aggiornamento: 2026-03-20
- Task ID: TASK-006
- Titolo: Database full import/export (multi-sheet)
- File task: `docs/TASKS/TASK-006-database-full-import-export.md`
- Stato: BLOCKED
- Motivo: implementazione completata e review emessa APPROVED da Claude; il crash di apply su dataset grande e' stato chiuso in TASK-022; follow-up reimport/idempotency in TASK-023 (**BLOCKED** 2026-03-24, test manuali pendenti); UX progress in TASK-024 (**BLOCKED** 2026-03-24, sospeso prima della finalizzazione review/fix UI).
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-008
- Titolo: Generated manual row dialog + calculate
- File task: `docs/TASKS/TASK-008-generated-manual-row-dialog-calculate.md`
- Stato: BLOCKED
- Motivo: review codice completata da Claude — nessun problema critico trovato, tutti i CA verificabili staticamente superati. Build verde. Validazione UI end-to-end (T-1..T-28) sospesa: richiede test manuali nel Simulator (l'automazione via wrapper SIM UI non è più parte del workflow standard). Sblocco subordinato a test manuali dell'utente o a decisione esplicita di procedere.
- Ultimo aggiornamento: 2026-03-22

## Pipeline standard del task
1. PLANNING (Claude) → definisce obiettivo, approccio, file coinvolti, criteri di accettazione
2. EXECUTION (Codex) → implementa secondo il planning, lavora contro i criteri
3. REVIEW (Claude) → verifica contro i criteri, classifica problemi, emette esito
4. FIX (Codex) → corregge quanto richiesto nella review → torna a REVIEW
5. Conferma finale utente → DONE

## Backlog
(Task futuri ordinati per priorità — aggiornabile solo da Claude o dall'utente, con motivazione esplicita)
Motivazione: TASK-002..013 proposti da TASK-001 (gap audit originale). TASK-015..021 proposti da TASK-014 (global audit approfondito, 2026-03-22). TASK-025..027 proposti da audit completo iOS vs Android (2026-03-25). TASK-029..035 creati da user override 2026-04-26 per cleanup tracking, completamento iOS, hardening import e preparazione Supabase. **TASK-036** aggiunto 2026-04-27 come follow-up documentale post-**TASK-031** (HTML avanzato: colspan/rowspan, multi-table, XCTest opzionale). **TASK-037** aggiunto 2026-04-27 da user override per creare il target XCTest minimale sulle fixture TASK-036. **TASK-040** aggiunto 2026-05-05: post TASK-039 DONE — full pull/paginazione controllata + bridge `remoteId` SwiftData allineato a inventory Supabase/Android; dipendenze TASK-034/035/038/039 DONE; riferimento funzionale Android TASK-067/068/069/070/071 (**non** copia codice).

| ID | Titolo | Stato | Priorità |
|----|--------|-------|----------|
| TASK-002 | External file opening (document handoff) | DONE | CRITICAL |
| TASK-003 | PreGenerate append/reload parity | DONE | HIGH |
| TASK-004 | GeneratedView editing parity (revert, delete, mark all, search nav) | DONE | HIGH |
| TASK-005 | ImportAnalysis error export + inline editing | BLOCKED | HIGH |
| TASK-006 | Database full import/export (multi-sheet) | BLOCKED | HIGH |
| TASK-007 | History advanced filters | DONE | MEDIUM |
| TASK-008 | Generated manual row dialog + calculate | BLOCKED | MEDIUM |
| TASK-009 | Product model old prices + price backfill | BLOCKED | LOW |
| TASK-010 | Localizzazione UI multilingua | DONE | LOW |
| TASK-011 | Large import stability, memory e progress UX | SUPERSEDED | HIGH |
| TASK-012 | Simulator automation — dual-agent wrapper + adapter (sblocca TASK-008) | DONE | HIGH |
| TASK-013 | sim_ui.sh performance — batch mode, timeout reale, cache device frame | WONT_DO | — |
| TASK-014 | Global Audit & Backlog Refresh | DONE | — |
| TASK-015 | Calculate dialog in GeneratedView (GAP-15 residuo) | WONT_DO | LOW |
| TASK-016 | Deduplicazione logica import DatabaseView/ProductImportViewModel | BLOCKED | LOW |
| TASK-017 | PreGenerate: validazione esplicita colonne obbligatorie | BLOCKED | MEDIUM |
| TASK-018 | GeneratedView: secondo livello revert (ai dati originali import) | BLOCKED | MEDIUM |
| TASK-019 | Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill | BLOCKED | MEDIUM |
| TASK-020 | Scanner: feedback camera non disponibile | BLOCKED | LOW |
| TASK-021 | HistoryEntry: warning su dati corrotti / deserializzazione fallita | BLOCKED | LOW |
| TASK-022 | Full-database large import: apply crash after analysis (EXC_BAD_ACCESS) | DONE | HIGH |
| TASK-023 | Full-database reimport idempotency + non-product diff visibility | BLOCKED | HIGH |
| TASK-024 | Full-database import progress UX + cancellation | BLOCKED | MEDIUM |
| TASK-025 | GeneratedView: ricalcolo dinamico paymentTotal + missingItems su History card | BLOCKED | MEDIUM |
| TASK-026 | Scanner: toggle torcia (flashlight) | BLOCKED | LOW |
| TASK-027 | ManualEntrySheet: modalità «Aggiungi e continua» (rapid entry) | BLOCKED | LOW |
| TASK-028 | GeneratedView: Row Detail UX Refinement vs Android | BLOCKED | HIGH |
| TASK-029 | iOS Completion Tracking Cleanup + Manual Validation Matrix | DONE | HIGH |
| TASK-030 | Full-database import/export finalization: reimport idempotency + non-product diff + progress UX | BLOCKED | HIGH |
| TASK-031 | Import recognition hardening: canonical headers HTML/Excel | DONE | MEDIUM |
| TASK-032 | GeneratedView multi-row navigation validation + missing-data scenarios | BLOCKED | MEDIUM |
| TASK-033 | Supabase schema audit and iOS/Android model mapping | DONE | HIGH |
| TASK-034 | Supabase iOS foundation: client config + DTO readonly | DONE | MEDIUM |
| TASK-035 | Manual Supabase pull to SwiftData dry-run | DONE | MEDIUM |
| TASK-036 | Import HTML advanced table parsing: colspan/rowspan/multi-table hardening | DONE | MEDIUM |
| TASK-037 | XCTest target for ExcelAnalyzer HTML parser fixtures | DONE | MEDIUM |
| TASK-038 | Supabase Google Auth foundation iOS | DONE | HIGH |
| TASK-039 | Supabase preview → apply locale controllato SwiftData | DONE | HIGH |
| TASK-040 | Supabase full pull + remote identity bridge SwiftData allineato Android/Supabase | DONE | HIGH |

## Task completati
| ID | Titolo | Data completamento |
|----|--------|--------------------|
| TASK-001 | Gap Audit iOS vs Android — Censimento funzionalità mancanti | 2026-03-19 |
| TASK-003 | PreGenerate append/reload parity | 2026-03-20 |
| TASK-004 | GeneratedView editing parity (revert, delete, mark all, search nav) | 2026-03-20 |
| TASK-007 | History advanced filters | 2026-03-21 |
| TASK-012 | Simulator automation — dual-agent wrapper + adapter | 2026-03-21 |
| TASK-002 | External file opening (document handoff) | 2026-03-22 (DONE parziale: "Condividi/Invia copia" funziona; "Apri con" cross-app documentato come limite iOS noto) |
| TASK-014 | Global Audit & Backlog Refresh | 2026-03-22 |
| TASK-022 | Full-database large import: apply crash after analysis (EXC_BAD_ACCESS) | 2026-03-23 |
| TASK-010 | Localizzazione UI multilingua | 2026-03-25 |
| TASK-029 | iOS Completion Tracking Cleanup + Manual Validation Matrix | 2026-04-26 |
| TASK-031 | Import recognition hardening: canonical headers HTML/Excel | 2026-04-27 |
| TASK-036 | Import HTML advanced table parsing: colspan/rowspan/multi-table hardening | 2026-04-27 |
| TASK-037 | XCTest target for ExcelAnalyzer HTML parser fixtures | 2026-04-27 *(slice 1); 2026-05-04 slice 2* |
| TASK-033 | Supabase schema audit and iOS/Android model mapping | 2026-05-03 |
| TASK-034 | Supabase iOS foundation: client config + DTO readonly | 2026-05-04 |
| TASK-035 | Manual Supabase pull to SwiftData dry-run | 2026-05-04 |
| TASK-038 | Supabase Google Auth foundation iOS | 2026-05-05 |
| TASK-039 | Supabase preview → apply locale controllato SwiftData | 2026-05-05 |
| TASK-040 | Supabase full pull + remote identity bridge SwiftData allineato Android/Supabase | 2026-05-05 |

## Blocchi e dipendenze
- TASK-032 bloccato / in pausa.
  Motivo: **User override 2026-05-03** — l'utente ha chiesto di mettere TASK-032 in pausa e attivare TASK-033. D2 e' accepted; **P2–P4 PASS runtime**; **P5 scanner reopen NON ha evidenza PASS** dopo tentativi di micro-fix. Task **non** DONE. Alla ripresa: chiudere o decidere formalmente P5 scanner reopen prima di qualunque raccomandazione finale su TASK-028.
- TASK-028 bloccato.
  Motivo: **User override 2026-04-26** — validazione runtime/visiva read-only positiva ma incompleta; build PASS; iPhone piccolo light/dark PASS; complete/incomplete PASS; campi secondari PASS sul caso completo; nessuna regressione TASK-028 rilevata; nessun FIX richiesto. Test residui sospesi: iPhone grande row detail, prev/next multi-riga, scanner reopen dopo decisione permesso camera, caso dati mancanti/ambigui. Task **non** DONE; pending manual validation finale.
  Nota (2026-05 TASK-032): slice **FIX D2** (`GeneratedView`/`InventorySearchSheet`) validata runtime con D2 PASS e D1 regression PASS. Override utente “Esegui tutto per farlo in DONE”: **P2–P4 PASS runtime** su iPhone 17 Pro Max, ma **P5 scanner reopen NON ha evidenza PASS** dopo tentativi di micro-fix; **TASK-032 ora BLOCKED / on hold** e **TASK-028 resta BLOCKED**. Non proporre DONE finché P5 scanner reopen non è validato o deciso formalmente con effetto esplicito.
  Nota: sospensione esplicita dell'utente; **TASK-029** e' completato e **TASK-030** e' ora **BLOCKED** per runtime gap canonico.
- TASK-027 bloccato.
  Motivo: implementation **completata**; review **completata** con esito **OK** / **APPROVED**; **test manuali T-1…T-13 non eseguiti** — **sospensione esplicita** perché mancano i test manuali; **non** **DONE**; **on hold for manual verification**. Alla ripresa: test manuali → eventuale FIX → REVIEW → conferma utente → DONE.
  Nota: planning tecnico invariato nel file task; nessun **DONE** finché mancano test manuali e conferma utente. *(Tracking allineato 2026-03-26.)*
- TASK-026 bloccato.
  Motivo: review **APPROVED** acquisita; **nessun fix** aperto; **test manuali T-1…T-9 pendenti**; **non** DONE. **In sospensione / pending manual validation**. Alla ripresa: test manuali → eventuale FIX → REVIEW → conferma utente → DONE.
  Nota: non invalida execution/review gia' documentati nel file task. *(Riferimento storico TASK-026; **non** descrive lo stato corrente — vedi **Obiettivo attuale** e **Workflow task attivo**: progetto **IDLE** dopo **TASK-040 DONE / Chiusura**.)*
- TASK-025 bloccato.
  Motivo: review tecnica **APPROVED** acquisita; **test manuali utente** (T-0..T-15) **pendenti**; **non** DONE. Task congelata in attesa validazione manuale. Alla ripresa: test → eventuale FIX → REVIEW finale → conferma utente → DONE.
  Nota: non invalida execution/review gia' documentati nel file task.
- TASK-021 bloccato.
  Motivo: **user override 2026-03-25** — sospeso per focus su **TASK-025**; review **APPROVED** (post-fix F-1) gia' acquisita; **non** DONE; alla ripresa: **conferma utente** (e eventuali test manuali documentati nel file task se ancora desiderati) → DONE.
  Nota: non invalida CA-1..CA-4 ne' l'execution/review gia' archiviati nel file task.
- TASK-020 bloccato.
  Motivo: **user override 2026-03-25** — review **APPROVED**; **nessun fix richiesto**; **test manuali T-1..T-6 pendenti**; **non** DONE. Alla ripresa: validazione manuale; se OK conferma utente, altrimenti FIX mirato → REVIEW.
  Nota: sospensione storica per attivare **TASK-021** (ora **TASK-021** e' **BLOCKED**); **TASK-027** **BLOCKED**. *(Riferimento storico: non descrive lo stato attuale del progetto — vedi **Obiettivo attuale**.)*
- TASK-019 bloccato.
  Motivo: **user override 2026-03-25** — review tecnica **APPROVED**; **nessun fix richiesto**; **test manuali pendenti**; **non** DONE. Alla ripresa: validazione manuale; se OK conferma utente, altrimenti FIX mirato → REVIEW.
  Nota: sospensione per attivare **TASK-020**; non invalida execution/review documentati nel file task.
- TASK-018 bloccato.
  Motivo: **user override 2026-03-25** — review **APPROVED**; test manuali **CA-7** (**S-1**, **M-1..M-10**, **M-12**) **pendenti**; **non** DONE. Alla ripresa: validazione manuale; se OK conferma utente, altrimenti FIX mirato.
  Nota: sospensione per spostare il focus operativo su **TASK-019**; non invalida l'execution/review gia' documentati nel file task.
- TASK-017 bloccato.
  Motivo: **user override 2026-03-24** — review **APPROVED**; test manuali utente **pendenti**; **non** DONE. Alla ripresa: validazione manuale PreGenerate (matrice T-1..T-10 a integrazione); se OK conferma utente, altrimenti FIX mirato.
  Nota: sospensione per spostare il focus operativo su **TASK-018**; non invalida il merge/review gia' documentati nel file task.
- TASK-016 bloccato.
  Motivo: **user override 2026-03-24** — deduplicazione import eseguita e review **APPROVED**; test manuali utente non completati; chiusura **DONE** differita. Alla ripresa: validazione manuale perimetro Excel/simple + consumer collegati; se OK conferma utente, altrimenti FIX mirato.
  Nota: sospensione per avviare TASK-017 su richiesta utente; non invalida il lavoro gia' mergiato in review.
- TASK-011 **SUPERSEDED**.
  Motivo: umbrella task completamente superato; il crash è stato chiuso in TASK-022 (DONE), reimport idempotency in TASK-023, progress UX in TASK-024. Nessun lavoro residuo non coperto dai task derivati. Aggiornato a SUPERSEDED da audit 2026-03-25.
  Nota tracking: il planning/execution storico di TASK-011 resta documentato nel suo file task.
- TASK-006 bloccato.
  Motivo: implementazione multi-sheet completata, review emessa APPROVED da Claude. Il crash specifico nell'apply su dataset grande e' stato chiuso in TASK-022; follow-up reimport/idempotency in TASK-023 (**BLOCKED** dal 2026-03-24 per test manuali pendenti). UX progress/cancel in TASK-024 (**BLOCKED** dal 2026-03-24; sospeso prima della finalizzazione review/fix UI).
  Nota criteri: CA-1/CA-12 e CA-14 verificati; TASK-011 resta contesto storico secondario.
- TASK-008 bloccato.
  Motivo: review codice completata da Claude — nessun problema critico trovato, tutti i CA verificabili staticamente superati. Build verde. Validazione UI end-to-end (T-1..T-28) sospesa: richiede test manuali nel Simulator (l'automazione via wrapper SIM UI non è più parte del workflow standard). Sblocco subordinato a test manuali dell'utente o a decisione esplicita di procedere.
  Nota criteri: CA-1..CA-14, CA-16..CA-20 verificati da code review; CA-15 (autosave/restore round-trip) e test interattivi T-1..T-28 ancora da validare manualmente.
  Ultimo aggiornamento: 2026-03-22

## Note di coordinamento
- Il file `docs/TASKS/TASK-TEMPLATE.md` è un MODELLO, non un task reale — non usarlo come task attivo
- Naming convention: `TASK-NNN-slug-descrittivo.md` (es. `TASK-001-login-session.md`)
- ID sempre a 3 cifre (`001`, `002`, `003`...) — mai riutilizzare un ID già assegnato
- Il nuovo task prende sempre il prossimo ID disponibile (verificare le tabelle Backlog e Task completati)
- Note operative dettagliate → nei file task, non qui
- Lavoro fuori scope emerso durante execution → registrare come follow-up, non inglobare
- I follow-up candidate non bloccano la chiusura del task, salvo che siano criteri di accettazione non soddisfatti
- Task in stato DONE restano archiviati in `docs/TASKS/` — non vanno riusati né modificati (salvo note documentali minime)
- Per nuovo lavoro collegato a un task DONE → creare un nuovo task con riferimento (campo "Dipende da"), non riaprire
- User override: se l'utente dà un'istruzione in conflitto col workflow, gli agent possono seguirla ma devono segnalare l'impatto
- 2026-04-26: TASK-029 completato come audit documentale/tracking-only. Matrice, tassonomia, test pack e raccomandazione prossima TASK-030 approvate. Nessun codice Swift/Supabase modificato.
- User override 2026-04-26: TASK-028 sospeso in BLOCKED dopo validazione runtime/visiva positiva ma incompleta. L'utente ha scelto di mettere in pausa i test residui e proseguire con i prossimi task di completamento iOS. Creati backlog TASK-029…TASK-035 per cleanup, completamento iOS, hardening import e preparazione Supabase.
- Tracking 2026-04-27: **TASK-036** promosso ad **ACTIVE / EXECUTION** come follow-up separato post-**TASK-031** DONE: parsing HTML avanzato (`colspan`/`rowspan`, scelta tabella, rumore pre-header). Nota: non creato un nuovo `TASK-032` per evitare collisione con il `TASK-032` GeneratedView gia' esistente.
- Handoff 2026-04-27: execution **TASK-036** completata da Cursor/Codex; build Debug Simulator PASS; fixture `docs/fixtures/TASK-036/` create; task passato a **REVIEW**.
- Chiusura 2026-04-27: **TASK-036** chiusa **DONE** dopo review tecnica con fix diretti piccoli; build Debug Simulator PASS; nessun Supabase / nessun `RowDetailSheetView` / nessun redesign PreGenerate.
- User override 2026-03-21: autorizzato riallineamento minimo del tracking da parte di Codex per evitare il blocco operativo tra file task e MASTER-PLAN durante l'avvio di TASK-008
- User override 2026-03-23: autorizzata da utente la sospensione di TASK-011 e la creazione/attivazione di TASK-022; backlog e tracking riallineati di conseguenza
- User override 2026-03-23: per TASK-022 il planning operativo viene svolto da Codex; il task resta in PLANNING fino all'avvio esplicito dell'execution
- User override 2026-03-23: autorizzata da utente la chiusura di TASK-022 in DONE e lo split dei follow-up in TASK-023 (attivo) e TASK-024 (backlog TODO), con aggiornamento diretto di tracking e backlog da parte di Codex
- User override 2026-03-24: TASK-023 messo in **BLOCKED** (test manuali non conclusi; non DONE); TASK-024 attivato come **task attivo** in **PLANNING** con file canonico `TASK-024-full-database-import-progress-ux-cancellation.md`; planning TASK-024 completato da Claude, execution non avviata
- User override 2026-03-24: TASK-024 sospeso in **BLOCKED** (review/fix UI non finalizzati; non DONE, riprendibile dal punto corrente) e TASK-016 attivato come **task attivo** in **PLANNING** con file canonico `TASK-016-deduplicazione-logica-import-databaseview-productimportviewmodel.md`
- User override 2026-03-24: TASK-016 messo in **BLOCKED** (review APPROVED, test manuali pendenti; non DONE); **TASK-017** attivato come **task attivo** in **PLANNING** con file `TASK-017-pregenerate-validazione-esplicita-colonne-obbligatorie.md`
- User override 2026-03-24: **TASK-017** messo in **BLOCKED** (review APPROVED, test manuali non eseguiti adesso; non DONE); creato file task **TASK-018** `TASK-018-generatedview-second-level-revert.md`; **TASK-018** attivato come **task attivo** in **PLANNING** con responsabile **CLAUDE** (planning dettagliato obbligatorio prima di EXECUTION)
- User conferma 2026-03-24: **TASK-018** planning **approvato**; fase **EXECUTION**, responsabile **CODEX**; vincoli execution/review nel file task (*Vincoli execution / review*)
- Tracking 2026-03-25: **TASK-018** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build OK; verifiche manuali `S-1` / `M-1..M-10` / `M-12` non eseguite in questo turno e restano aperte.
- User override 2026-03-25: **TASK-018** messo in **BLOCKED** (review **APPROVED**, test manuali CA-7 pendenti; **non** DONE); **TASK-019** attivato come **task attivo** con file `TASK-019-robustezza-guardie-generatedview-cascade-delete-async-backfill.md` (bootstrap da backlog/TASK-014). Tracking 2026-03-25: planning tecnico TASK-019 completato; execution Codex completata; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; review richiesta su adattamento minimo Fix B per limite macro SwiftData sull'inverse reciproco.
- User override 2026-03-25: **TASK-019** messo in **BLOCKED** (review tecnica **APPROVED**, **nessun fix richiesto**, test manuali **non eseguiti**; **non** DONE); **TASK-020** attivato come **task attivo** in **PLANNING** con file `TASK-020-scanner-feedback-camera-non-disponibile.md` (bootstrap da TASK-014 gap N-10); responsabile **CLAUDE** fino a planning operativo completo e handoff verso EXECUTION.
- Tracking 2026-03-25: **TASK-020** planning operativo completato (stati scanner, architettura `ScannerView`/`BarcodeScannerView`, CA, matrice test, rischi); fase **EXECUTION**, responsabile **CODEX**.
- Tracking 2026-03-25: **TASK-020** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; verifiche statiche sui CA documentate nel file task; test manuali `T-1..T-6` non eseguiti in questo turno.
- Tracking 2026-03-25: **TASK-020** review completata da **CLAUDE**: **APPROVED**, nessun fix richiesto. In attesa **conferma utente** + test manuali `T-1..T-6`.
- User override 2026-03-25: **TASK-020** messo in **BLOCKED** (review **APPROVED**, **nessun fix richiesto**, test manuali **T-1..T-6 non eseguiti**; **non** DONE); **TASK-021** attivato come **unico task attivo** in **PLANNING** con file `TASK-021-historyentry-warning-dati-corrotti-deserializzazione.md` (bootstrap da backlog/TASK-014 gap N-12/DT-07); responsabile **CLAUDE**.
- Tracking 2026-03-25: **TASK-021** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; verifiche statiche su CA-1..CA-4 documentate nel file task; test runtime/manuali e verifica store esistente non eseguiti in questo turno.
- Tracking 2026-03-25: **TASK-021** review completata da **CLAUDE**: **CHANGES_REQUIRED** (un fix: scope creep export blocking). → **FIX** / CODEX.
- Tracking 2026-03-25: **TASK-021** fix **F-1** applicato (rimosso export blocking + `.exportBlocked` + stringhe localizzazione); build OK. → **REVIEW** post-fix / CLAUDE.
- Tracking 2026-03-25: **TASK-021** review post-fix completata da **CLAUDE**: **APPROVED**. CA-1..CA-4 soddisfatti. In attesa **conferma utente**. Test manuali T-5 (store migration) e scenari runtime T-1..T-3/T-7 restano rischi noti non eseguiti.
- User override 2026-03-25: **TASK-021** messo in **BLOCKED** (review **APPROVED** acquisita; **non** DONE; conferma utente differita); **TASK-025** attivato come **unico task attivo** in **PLANNING** con file `TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`; planning tecnico (inclusa formula **paymentTotal** allineata Android, SSOT, UI History, **GeneratedView.summarySection** strategia A, contratto difensivo **RuntimeSummary**) documentato da **CLAUDE**.
- Tracking 2026-03-25: **TASK-025** riallineato in **EXECUTION**; responsabile **CODEX**. Scope confermato: summary runtime (`paymentTotal` / `missingItems` / `totalItems`), SSOT su `saveChanges()`, stato iniziale coerente, chip `missingItems` in `HistoryView`, layout card a due righe, anti-regressione `GeneratedView.summarySection`.
- Tracking 2026-03-25: **TASK-025** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; implementati helper runtime summary, integrazione `saveChanges()`/`generateHistoryEntry`/revert, chip `missingItems` in `HistoryView`, layout card a due righe e anti-regressione `GeneratedView.summarySection`. Verifiche Simulator/manuali non eseguite in questo turno.
- Tracking 2026-03-25: **TASK-025** review tecnica completata da **CLAUDE**: **APPROVED**. CA-1..CA-9 verificati staticamente; formula `paymentTotal` conforme Decisione #1; SSOT su `saveChanges()` coerente; contratto difensivo rispettato; guardrail handoff rispettati; build OK; nessun fix richiesto. In attesa **test manuali utente** (T-0..T-15) e **conferma utente**.
- User override 2026-03-25: **TASK-025** messo in **BLOCKED** (review **APPROVED** acquisita; test manuali **non eseguiti**; **non** DONE). **TASK-026** attivato come **unico task attivo** in **PLANNING** con file `TASK-026-scanner-toggle-torcia-flashlight.md`; bootstrap planning iniziale; responsabile **CLAUDE**.
- Tracking 2026-03-25: **TASK-026** — planning **completato**; handoff **EXECUTION** registrato; stato **ACTIVE**, fase **EXECUTION**, responsabile **CODEX**; parte preparatoria (documentazione + **MASTER-PLAN**) chiusa da **CLAUDE**; **prossimo step = execution Codex** (nessun avvio implementazione in questo aggiornamento).
- Tracking 2026-03-25: **TASK-026** review **APPROVED** (nessun fix); task messo in **BLOCKED** — **test manuali T-1…T-9 non eseguiti**; **pending manual validation**. **TASK-027** attivato come unico **ACTIVE** in **PLANNING** con file `TASK-027-manualentrysheet-aggiungi-e-prossimo.md`; responsabile **CLAUDE** fino a planning completo e handoff verso **EXECUTION**.
- Tracking 2026-03-25: **TASK-027** — planning **completato e approvato** dall'utente; transizione **PLANNING → EXECUTION**; responsabile **CODEX**; handoff post-planning nel file task dichiarato **valido**; aggiornamento **solo tracking** (nessun ripensamento tecnico/UX nel planning).
- Tracking 2026-03-25: **TASK-027** — execution **completata**; review **APPROVED** (OK); test manuali **non eseguiti**; task messo in **BLOCKED** (**pending manual verification**); **non** **DONE**. *(Subito dopo è stato attivato **TASK-028** come unico **ACTIVE**.)*
- Tracking 2026-03-26: riallineamento documentazione **TASK-027** (stato ufficiale: implementation + review OK; test manuali **non eseguiti**; **non** **DONE**; motivo blocco = test manuali mancanti). **TASK-028** confermato **unico task ACTIVE** (REVIEW **APPROVED**, UTENTE); nessun altro ID del backlog promosso ad **ACTIVE** senza superare blocchi o dipendenze.
- Tracking 2026-03-25: **TASK-010** chiusa in **DONE** su conferma utente. Regressione localizzazione verificata come risolta: root cause = delimitatori Unicode invalidi in 3 `Localizable.strings` non inglesi; hotfix minimo applicato e verificato, nessun task figlio aperto.
- Tracking 2026-03-26: **TASK-028** creato e attivato come **unico task ACTIVE** in **PLANNING** con file `TASK-028-generatedview-row-detail-ux-refinement.md`; responsabile **CLAUDE**. Planning tecnico completato: audit comparativo Android vs iOS, target UX, 5 execution slices (A-E), 9 criteri di accettazione. Handoff verso **EXECUTION** / **CODEX** pronto — in attesa conferma utente per procedere.
- Audit 2026-03-25: **audit completo iOS vs Android** eseguito su richiesta utente. Confronto granulare di tutte le aree funzionali (inventario, database, cronologia, scanner, import/export, opzioni, sync, storico prezzi). Risultato: iOS copre ~95% delle feature Android. Gap residui: (1) paymentTotal non ricalcolato dinamicamente, (2) assenza toggle torcia nello scanner, (3) rapid entry manuale affrontata da **TASK-027** (copy «Aggiungi e continua»; task **BLOCKED** — validazione manuale pendente). Creati **TASK-025**, **TASK-026**, **TASK-027**. Aggiornati: **TASK-011** → SUPERSEDED, **TASK-013** → WONT_DO.

## Criterio di aggiornamento
Questo file va aggiornato SOLO quando cambia almeno uno di:
- Task attivo (nuovo, cambiato, rimosso)
- Fase attuale del task attivo
- Stato di un task (TODO → ACTIVE → BLOCKED → DONE)
- Blocchi o dipendenze
- Avanzamento reale del progetto
- Backlog o priorità (solo Claude o utente, con motivazione)
NON aggiornare per note operative, dettagli di implementazione, o micro-progressi.
