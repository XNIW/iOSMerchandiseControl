# TASK-085 — Hardening production-ready iOS / Supabase / cross-platform

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-085 |
| **Titolo** | Hardening production-ready iOS / Supabase / cross-platform |
| **File task** | `docs/TASKS/TASK-085-production-ready-hardening-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura — LATER_GAPS_CLOSED_BY_TASK086_103 |
| **Responsabile attuale** | Nessuno / Chiuso |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-12 19:18 -0400 — legacy alignment: historical PARTIAL_ACCEPTED gaps consumed by TASK-086...TASK-103 evidence; no global production-ready claim; vedi `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md` |
| **Ultimo agente** | Codex / Reviewer |
| **Repo iOS target** | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| **Repo Android riferimento** | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| **Supabase locale riferimento** | `/Users/minxiang/Desktop/MerchandiseControlSupabase` *(schema/reference; remoto `merchandisecontrol-dev` usato solo per seed controllato `TASK085_*` su override utente)* |

> **Chiusura legacy 2026-05-12:** le sezioni storiche sottostanti restano archivio; la fonte di verita' corrente e' `Chiusura — LATER_GAPS_CLOSED_BY_TASK086_103` secondo `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md`.

---

## Dipendenze

- **Dipende da:** **TASK-084 DONE / Chiusura** — review documentale read-only P84-A/P84-B/P84-C; gap summary e routing approvati; **nessuna** equivalenza a parità runtime completa.
- **Considera TASK-083 DONE / Chiusura** come smoke end-to-end **bloccato da manifest incompleto** (preflight): S83-01 **BLOCKED**, S83-02…S83-06 **NOT RUN**; lezione H85 = manifest H85 completo prima di dichiarare PASS runtime.
- **TASK-078…TASK-082** = base implementativa sync mutativa Release iOS (pull apply, push catalogo, ProductPrice, drain outbox, conflitti/timestamp); TASK-085 **non le riapre** ma ne trae criteri di hardening e regression pack.
- **TASK-085 non riapre TASK-084** e non riesegue scenari P84 salvo override esplicito e gate separati.
- **TASK-085 non deve dichiarare** parità Android ↔ iOS runtime completa né smoke cross-platform PASS senza evidenze dedicate.

---

## Obiettivo

Definire inizialmente il piano di hardening production-ready per la roadmap Supabase iOS / cross-platform e, su successivi override utente, eseguire le slice S85-A...S85-G con patch piccole, evidenze privacy-safe e stato finale onesto. La chiusura del task non equivale a claim "production-ready 100%".

Il perimetro copre:

- **Performance** su dataset grande (import/export, preview/apply, UI reattiva);
- **Stabilità** UI e feedback di progresso durante operazioni lunghe;
- **Recovery** dopo crash, annullamento e retry controllato;
- **Osservabilità** privacy-safe (log/redazione, conteggi aggregati, niente dati reali in evidenze);
- **Offline → online manuale** senza introdurre sync automatica in background;
- **Regressioni complete** (pack manuale + automatiche dove già previste) allineate a TASK-078…082 e gap TASK-084;
- Stato finale obiettivo **«100% checklist»** della roadmap = checklist firmata con **evidenze** per ogni voce critica, non solo caselle compilate;
- **UX Release senza gergo** tecnico visibile (coerente TASK-074/076/083);
- **Follow-up** espliciti per i gap emersi da TASK-084 (routing iOS / Android / Supabase / manifest / test).

---

## Integrazione review ChatGPT — ottimizzazioni planning

Integrazione **solo documentale**; non modifica lo stato **PLANNING / markdown-only** del task e non autorizza execution.

- **Perimetro invariato:** TASK-085 resta **planning-only**; nessuna patch Swift/Kotlin/SQL, nessun `xcodebuild` obbligatorio, nessun TASK-086.
- **Soglie seed misurabili:** per la futura execution vanno definiti e poi **validati con evidenze** obiettivi quantitativi/qualitativi su **performance** (tempo/cardinalità), **memoria** (OOM / footprint indicativo), **responsività UI** (primo feedback, main-thread), **recovery** (crash/kill, cancel/retry) — vedi § «Soglie seed per futura execution» e **D85-16**.
- **Piccoli polish UI/UX futuri:** autorizzati in **execution futura** se migliorano **chiarezza**, **accessibilità**, **feedback** operatore o **coerenza** con lo **stile iOS esistente** nell’app (non redesign non richiesto) — **D85-13**.
- **Android:** resta **riferimento funzionale** (contratti dati, flussi di dominio), **non** layout o UI da copiare **1:1** — **D85-14**.
- **Micro-scelte UI/UX:** in execution futura l’agente **sceglie autonomamente** la soluzione **più Apple-native** e coerente con il resto dell’app, documentando la scelta nei handoff/review del task di execution — **D85-14**, § «Regole UI/UX per futura execution».

---

## Stato iniziale

- **TASK-084** è **DONE / Chiusura** come **review documentale read-only** (P84-A mapping statico, P84-B manifest M1…M17 documentale **NOT RUN**, P84-C schede **PLANNED / NOT RUN**).
- **TASK-084 non equivale** a parità runtime Android ↔ iOS completa, né a smoke cross-platform PASS.
- **Gap principali rimasti** (da TASK-084 gap summary, riportati qui come input al hardening; S85-B/S85-C2 hanno ridotto alcuni gap ma non chiuso la readiness runtime):
  - **ProductPrice `remoteID`** iOS (`MISSING_IOS` originario) → **ridotto da S85-B / PARTIAL**: apply/dry-run iOS collegano remote row id, ma post-push manuale/unique constraint/runtime store restano da evidenziare.
  - **`updated_at` catalogo** Android (`MISSING_ANDROID` originario) → **ridotto da S85-C2 / PARTIAL**: DTO/ref Android propagano `updated_at`, ma collaudo Supabase sandbox reale e policy backend `updated_at` restano BLOCKED_ENV/PARTIAL.
  - **HistoryEntry cloud** non definitivo — `sql/005_history_entries.sql` draft, nessun contratto pubblico stabile (`SCHEMA_GAP`).
  - **ProductPrice** senza `updated_at` / `deleted_at` tabellare — tombstone prezzo via eventi, non colonna; ordering/conflict policy richiede evidenze (`SCHEMA_GAP` / `PARTIAL`).
  - **Import/export** e **current/previous price** ancora **PARTIAL** (es. export iOS senza colonne old price / id fornitore-categoria come Android round-trip).
- **TASK-085** pianifica hardening e readiness **documentale**; **non** implementa patch in questa fase PLANNING.

---

## Perimetro planning

**Incluso:**

- Planning hardening production-ready (aree, priorità, soglie future, evidenze).
- Classificazione gap TASK-084 in **follow-up** / task futuri candidati.
- Matrice performance / recovery / osservabilità (tabella «Matrice hardening»).
- Checklist production-ready finale (criteri + gate evidenze).
- Scenari **H85-01…H85-17** tutti **PLANNED / NOT RUN**.
- Decisioni **D85-01…D85-17** (incl. seed/UI/UX/tranche).
- Soglie seed future § «Soglie seed per futura execution»; regole UI/UX future § «Regole UI/UX per futura execution»; ordine execution § «Ordine consigliato di futura execution».
- Rischi e **handoff** verso review planning.

**Escluso (questo turno e salvo task futuro):**

- Execution Codex, patch **Swift** / **Kotlin**, **SQL live**, **write Supabase**, smoke/runtime obbligatori, **`xcodebuild` obbligatorio**.
- **Sync automatica / background** (Timer, BGTask, Realtime, worker, polling) salvo **task separato** esplicitamente autorizzato.
- Dataset **negozio reale** senza gate e consenso separati.
- **Cleanup / reset / truncate / delete** distruttivo come strategia di recovery.
- Apertura automatica di **TASK-086+** o backlog senza decisione utente/reviewer.

---

## Fuori perimetro severo

- Sync automatica/background non autorizzata.
- Timer / BGTask / Realtime / worker / polling non autorizzati per “completare” sync manuale.
- Modifiche Swift/SwiftUI/SwiftData.
- Modifiche Android/Kotlin.
- Modifiche SQL/backend/Supabase **live**.
- Modifiche `Localizable.strings` / `project.pbxproj`.
- Runtime UI obbligatorio in questo planning.
- Dataset negozio reale.
- Claim **«production-ready 100%»** senza evidenze privacy-safe per scenario critico.
- Claim **«parità Android ↔ iOS completa»**.
- Cleanup distruttivo come fix.

---

## Matrice hardening production-ready

*Stato attuale = noto da TASK-078…084 documentale / codice statico; runtime H85 = NOT RUN fino a execution futura. **33 aree** minime (25 iniziali + 8 integrazione UX/flow/technical).*

| # | Area | Stato attuale noto | Rischio production | Segnale/evidenza richiesta | Gap TASK-084 collegato | Priorità | Follow-up proposto |
|---|------|-------------------|---------------------|---------------------------|------------------------|----------|---------------------|
| 1 | Dataset grande import/export | iOS import/export funzionali; round-trip cross-client PARTIAL | Timeout OOM, UX blocco, file corrotti | Tempo/memoria/steps aggregati su H85DATA-LARGE; esito IMPORT/EXPORT | Export/import PARTIAL | P0 | Task iOS formato export + fixture H85; task manifest |
| 2 | Dataset grande sync preview | Preview/apply implementati Release; volume grande non evidenziato end-to-end | UI frozen, summary fuorviante, partial non chiaro | Profilo tempo su preview+sheet; conteggi skip/block | Performance OUT_OF_SCOPE_084 → H85 | P0 | Scenario H85-02 + soglie numeriche |
| 3 | Pull apply catalogo | TASK-078 DONE; guards stale/sessione TASK-082; Android timestamp bridge ridotto in S85-C2 | Apply errato se baseline/sessione incerta | PASS/PARTIAL con recheck obbligatorio + collaudo sandbox | Catalog `updated_at` Android PARTIAL / live BLOCKED_ENV | P0 | H85-09 + collaudo sandbox timestamp |
| 4 | Push catalogo | TASK-079 DONE | Partial write, UX non onesta | Summary post-push aggregato; nessun dump payload | — | P0 | H85-02, H85-08 |
| 5 | ProductPrice apply/push | TASK-080/082 DONE staticamente; remote row id iOS ridotto in S85-B | Dedupe/conflict senza remote row id iOS completo | Conteggi applied/skipped/blocked; stress H85DATA-PRICE-STRESS | ProductPrice remote id PARTIAL | P0 | H85-03 + post-push/manual identity evidence |
| 6 | ProductPrice current/previous | Derivazione storico vs campi snapshot; export iOS senza old columns | Listino errato per operatore | Confronto snapshot vs history dopo M8–M10 class | current/previous PARTIAL | P0 | H85-03, H85-10, possibile task schema/policy |
| 7 | Outbox drain | TASK-081 DONE | Head-of-line, partial drain non visibile | Summary **registrate / in attesa / non registrabili** + retry | sync_events MATCH statico; runtime NOT RUN | P1 | H85-04, D85-09 |
| 8 | Crash recovery | Parziale: pattern cancel TASK-075; persistenza piano volatile da verificare su crash reale | Stato DB vs aspettative utente | Ripresa post-crash senza cleanup distruttivo | — | P0 | H85-05, stop D85-05 |
| 9 | Cancel/retry recovery | CTA Riprova / flussi TASK-078…081 | Doppio apply se stale non gestito | Sequenza cancel → retry con recheck baseline | — | P0 | H85-06 |
| 10 | Offline/online manuale | Manual-first policy; nessuna auto-sync | Utente crede sync avvenuta senza rete | Indicatore chiaro “nessun invio automatico”; retry solo manuale | — | P0 | H85-07, D85-01–02 |
| 11 | Session/account/owner guard | TASK-082 fail-closed | RLS leak percepito / dati altri owner | STOP su owner mismatch; evidenza classe errore | owner_user_id MATCH statico | P0 | H85-08 |
| 12 | Baseline stale | Piano volatile invalidabile | Apply su piano vecchio | Ricontrollo obbligatorio pre-write | timestamp policy PARTIAL | P0 | H85-09 |
| 13 | Conflict/timestamp/tombstone | Catalog tombstone OK; ProductPrice tombstone SCHEMA_GAP | Conflitti silenziosi | Manifest H85DATA-CONFLICT | SCHEMA_GAP prezzi | P0 | Task backend/eventi + H85-03 |
| 14 | HistoryEntry locale/cloud | Locale SwiftData; cloud draft | Aspettative inventario sessioni | Nessun claim cloud fino a schema | HistoryEntry SCHEMA_GAP | P1 | Task Supabase design |
| 15 | Import Excel header mapping | Alias non identici Android/iOS | Righe scartate male | Fixture H85DATA-IMPORT-EXPORT | import Excel PARTIAL | P1 | H85-10, manifest righe errore |
| 16 | Import analysis errori/duplicati | Dedupe last-row entrambi; validazione Android più stretta | Duplicati silenziosi o righe perse | Conteggi create/update/error | — | P1 | H85-10 |
| 17 | Export/reimport idempotente | PARTIAL cross-format | Doppioni attivi | Round-trip due passaggi | export PARTIAL | P1 | H85-10 |
| 18 | Scanner/manual entry | Fuori core sync H85; tocca stabilità inventario | Errori battitura / scan | Smoke mirato locale minimo | — | P2 | Regressione inventario separata se necessario |
| 19 | UX no-jargon Release | Policy TASK-074/076 | Fiducia / errori operatore | Grep/copy review + screenshot oscurati | — | P0 | H85-11 |
| 20 | Accessibility/Dynamic Type | XCTest/linee guida TASK-067+ | Testo troncato, CTA illeggibili | Pass a11y su sheet/card sync | — | P1 | H85-11 |
| 21 | Localizzazioni IT/EN/ES/zh-Hans | Copertura test `plutil` storica | Stringhe mancanti in Release | Matrice chiave summary/error | — | P1 | H85-12 *(senza edit strings in questo task)* |
| 22 | Privacy-safe logging | Conteggi senza payload | Leak PII | Policy redazione + esempio evidenza | — | P0 | H85-13, formato evidenze |
| 23 | Performance memory/time | Non quantificato su LARGE | Crash/lag | Strumenti + soglie documentate | OUT_OF_SCOPE_084 | P0 | H85-01, H85-02 |
| 24 | Regression test suite | XCTest TASK-078…082; S83 bloccati | Regressione silenziosa | Elenco test + esito BUILD opzionale futuro | TASK-083 manifest | P0 | H85-14 |
| 25 | Final release checklist | Roadmap: «Definizione di 100%» in MASTER-PLAN | Claim infondati | Checklist 100% con evidenza per voce | Tutti gap | P0 | H85-15 |
| 26 | UX flow Home → import → preview → generated → DB | Tab inventario e Database esistono; attraversamento end-to-end non hardenato in H85 | Percorso frammentato, stato perso, confusione operatore | Walkthrough H85-16 con **H85DATA-UX-FLOW**; screenshot oscurati | import/export PARTIAL | P1 | H85-16 |
| 27 | Feedback progresso operazioni lunghe | Pattern TASK-075/078; coerenza globale non quantificata | Utente ripete tap o crede freeze | Primo feedback ~500ms; fase visibile >2s (**D85-15**, soglie seed) | — | P0 | H85-01, H85-02, H85-17 |
| 28 | Responsiveness griglia Excel / Generated | `GeneratedView` / griglia grande: rischio lag | Editing e scan frustranti | Scroll/edit su MEDIUM/LARGE; giudizio frame in execution | Performance OUT_OF_SCOPE_084 | P0 | H85-17, H85-02 |
| 29 | Import Excel memory-safe / streaming / chunking | Parser concentrato in `ExcelSessionViewModel`; strategia memory da validare | OOM su file grandi | Import LARGE: completamento o stop + errore chiaro (soglie seed) | import Excel PARTIAL | P0 | H85-01, follow-up chunking iOS |
| 30 | Errori import con correzione guidata | Analysis/errors in UI; validazione ≠ Android | Righe perse senza recovery | Conteggio errori + percorso «correggi e riprova» in evidenza | import Excel PARTIAL | P1 | H85-10, polish UX futuro |
| 31 | Share/export/import Apple-native | Export/share presenti; allineamento HIG da verificare | Flussi poco familiari su iOS | **ShareLink** / **FileImporter** / **FileExporter** dove applicabile | export PARTIAL | P1 | H85-16; sezione «Regole UI/UX per futura execution» |
| 32 | State restoration / draft safety | Sessione inventario locale; crash mid-flow da caratterizzare | Lavoro perso o incoerente | Ripresa post-kill senza cleanup distruttivo; stato draft chiaro | HistoryEntry cloud SCHEMA_GAP | P1 | H85-05, H85-16 |
| 33 | Decisioni UI/UX autonome in execution futura | Scelte polish non fissate nel planning | Incoerenza se non tracciata | Nota in handoff/PR per micro-scelte — **D85-13 / D85-14** | — | P2 | Tranche polish **D85-17** |

## Gap routing da TASK-084

Portare i gap principali TASK-084 nel backlog di hardening **senza implementazione** in TASK-085.

### G1 — ProductPrice.remoteID non persistito su iOS

| Voce | Contenuto |
|------|-----------|
| **Origine** | TASK-084 P84-A ProductPrice / field mapping (`MISSING_IOS`) |
| **Impatto** | Asimmetria con Android `ProductPriceRemoteRef`; push/dedupe/diagnostica possono divergere; evidenze cross-client più difficili |
| **Severità** | Alta per production su volumi e conflitti |
| **Task target futuro** | Task iOS dedicato (persistenza remote id riga prezzo + migrazione SwiftData se autorizzata) |
| **Blocca readiness?** | **Sì** per dichiarare parity prezzi “completa” e per ridurre rischio silenzioso su storico; **non** blocca la sola checklist documentale H85 se la voce resta PARTIAL con evidenza |

### G2 — updated_at catalogo Android

| Voce | Contenuto |
|------|-----------|
| **Origine** | TASK-084 — `InventoryProductRow` / supplier/category row senza `updated_at` mappato; **S85-C2** ha aggiunto mapping/propagazione Android lato codice |
| **Impatto** | Policy stale/conflict cross-device puo' essere asimmetrica finche' manca collaudo sandbox reale e finche' il contratto backend `updated_at` non e' confermato su update normali |
| **Severità** | Media–alta per conflitti timestamp |
| **Task target futuro** | Collaudo sandbox Android ↔ Supabase ↔ iOS + conferma policy backend `updated_at` |
| **Blocca readiness?** | **Parziale** — il blocker Kotlin e' ridotto, ma blocca ancora claim di parita' conflitti **simmetrici** fino a evidenza live privacy-safe |

### G3 — HistoryEntry cloud non definitivo

| Voce | Contenuto |
|------|-----------|
| **Origine** | TASK-084 — draft SQL `005_history_entries.sql`, nessuna tabella pubblica stabile |
| **Impatto** | Nessun inventario sessioni cross-device via Supabase con contratto chiaro |
| **Severità** | Media per roadmap “100%” se HistoryEntry cloud è nel perimetro prodotto |
| **Task target futuro** | Task Supabase/backend **design + migration** (fuori repo iOS) |
| **Blocca readiness?** | **Sì** per checklist che richiedono sync inventario sessioni cloud; **no** per checklist limitata a catalogo/prezzi/outbox |

### G4 — ProductPrice senza updated_at / deleted_at tabellare

| Voce | Contenuto |
|------|-----------|
| **Origine** | TASK-084 — schema + eventi `prices_tombstone` senza colonna tombstone |
| **Impatto** | Ordering e delete prezzo dipendono da `effective_at` ed eventi; edge case più complessi |
| **Severità** | Alta per scenari delete/conflitto prezzo |
| **Task target futuro** | Task backend/policy (event-only vs schema evolution) + evidenze H85-03 |
| **Blocca readiness?** | **Parziale** — richiede evidenze esplicite su delete/tombstone, non supposizioni |

### G5 — Import/export e current/previous price PARTIAL

| Voce | Contenuto |
|------|-----------|
| **Origine** | TASK-084 — export iOS senza colonne old price; validazione import diversa |
| **Impatto** | Round-trip file e listino operatore possono divergere tra piattaforme |
| **Severità** | Media |
| **Task target futuro** | Task formato file / test manifest H85DATA-IMPORT-EXPORT + eventuale iOS export esteso |
| **Blocca readiness?** | **Parziale** — finché H85-10 resta PARTIAL documentato, non si dichiara round-trip “chiuso” |

---

## Scenari H85

*Tutti gli scenari seguenti (**H85-01…H85-17**): **stato iniziale PLANNED / NOT RUN**; esecuzione solo in task futuro con override.*

### H85-01 — Performance dataset grande import/export iOS

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Quantificare tempo e stabilità import/export (Products, Full DB, PriceHistory) su volume grande con soglie accettate documentate |
| **Dataset richiesto** | **H85DATA-LARGE** (+ varianti H85DATA-SMALL/MEDIUM per baseline) |
| **Preflight** | Manifest approvato; device/simulator noto; nessun dato negozio reale; build identificata |
| **Check atteso** | Completamento o exit controllato (PARTIAL documentato); nessun silent corrupt export |
| **Stop conditions** | OOM, hang > soglia, richiesta cleanup distruttivo, dataset reale non autorizzato |
| **Evidenza privacy-safe** | Solo conteggi righe/tempo/memoria indicativa; file path generico; screenshot oscurati |
| **Stato** | **PLANNED / NOT RUN** |

### H85-02 — Performance sync preview/apply su dataset medio/grande

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Profilo Controlla cloud → Rivedi → apply su cardinalità media/grande; UI responsive |
| **Dataset richiesto** | **H85DATA-MEDIUM**, **H85DATA-LARGE** |
| **Preflight** | Sessione/owner noti; baseline; manifest |
| **Check atteso** | Summary onesto (`applied` / `skipped` / `blocked`); tempi sotto soglia o PARTIAL spiegato |
| **Stop conditions** | Piano stale, owner mismatch, auto-sync proposto come workaround |
| **Evidenza privacy-safe** | Conteggi aggregati per sezione; nessun barcode reale in chiaro |
| **Stato** | **PLANNED / NOT RUN** |

### H85-03 — ProductPrice stress / dedupe / current previous

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Stress storico prezzi: duplicati logici, effective_at vicini, current vs previous |
| **Dataset richiesto** | **H85DATA-PRICE-STRESS** |
| **Preflight** | Product remote id presente; keys sandbox |
| **Check atteso** | Conteggi TASK-080/082 coerenti; nessun doppio storico “fantasma” |
| **Stop conditions** | Incertezza schema tombstone; tentativo di risolvere solo con background sync |
| **Evidenza privacy-safe** | # righe storico, # skippedDuplicate, # blocked (aggregati) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-04 — Outbox drain recovery e partial handling

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Validare drain manuale con partial, retry, head-of-line; summary leggibile |
| **Dataset richiesto** | **H85DATA-OUTBOX-PARTIAL** |
| **Preflight** | Auth; owner; outbox non truncato con cleanup vietato |
| **Check atteso** | Sezioni summary visibili; stato post-partial recuperabile senza auto-retry |
| **Stop conditions** | Richiesta reset outbox distruttivo |
| **Evidenza privacy-safe** | Solo conteggi coda per stato (es. registrate/in attesa) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-05 — Crash recovery durante preview/apply/push/drain

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Verificare ripartenza sicura dopo kill app in fasi lunghe |
| **Dataset richiesto** | **H85DATA-MEDIUM** o **LARGE** |
| **Preflight** | Checkpoint scenari noti; nessuna aspettativa di completamento transazione implicita non documentata |
| **Check atteso** | DB non corrotto; utente guidato a **Controlla cloud** / **Riprova** senza dati fantasma |
| **Stop conditions** | Recovery richiede truncate/delete |
| **Evidenza privacy-safe** | Fase interrotta + esito ripresa (senza payload) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-06 — Cancel/retry durante operazione lunga

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Confermare pattern TASK-075 su percorsi mutativi TASK-078…081 |
| **Dataset richiesto** | **H85DATA-MEDIUM** |
| **Preflight** | CTA annulla disponibile |
| **Check atteso** | Stato `cancelled` o equivalente user-facing; **Riprova** riparte da preview pulita |
| **Stop conditions** | Doppio apply senza recheck |
| **Evidenza privacy-safe** | Sequenza stati (testo UI generico) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-07 — Offline → online manuale, senza auto-sync

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Garantire che nessun write avvenga senza azione utente dopo reconnettere |
| **Dataset richiesto** | **H85DATA-OFFLINE** |
| **Preflight** | Flight mode / disconnessione controllata |
| **Check atteso** | Copy “nessun invio automatico” rispettato; sync solo dopo CTA esplicita |
| **Stop conditions** | Qualsiasi workaround con Timer/BGTask/Realtime/polling |
| **Evidenza privacy-safe** | Stato rete (on/off) + esito CTA (no token) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-08 — Sessione scaduta / owner mismatch / RLS fail-closed

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Verificare guard TASK-082: niente apply/push silenziosi sotto identità errata |
| **Dataset richiesto** | **H85DATA-SMALL** + sessione di test controllata |
| **Preflight** | Simulazione scadenza / cambio account in modo sicuro |
| **Check atteso** | Blocco esplicito; CTA **Accedi di nuovo** / **Ricontrolla** coerenti |
| **Stop conditions** | RLS o owner non riproducibili in sandbox |
| **Evidenza privacy-safe** | Classe errore; nessun owner UUID reale |
| **Stato** | **PLANNED / NOT RUN** |

### H85-09 — Baseline stale e ricontrollo obbligatorio

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Impedire apply/push su piano volatile obsoleto |
| **Dataset richiesto** | **H85DATA-CONFLICT** |
| **Preflight** | Due writer o seed timestamp controllati |
| **Check atteso** | Richiesta nuovo **Controlla cloud** prima di write |
| **Stop conditions** | Schema timestamp non chiaro (G2/G4 non risolti) |
| **Evidenza privacy-safe** | Esito “stale” o blocco (aggregato) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-10 — Import/export DB round-trip idempotente

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Due cicli export→import senza moltiplicazione entità attive |
| **Dataset richiesto** | **H85DATA-IMPORT-EXPORT** |
| **Preflight** | Fixture solo chiavi sandbox |
| **Check atteso** | Conteggi prodotti/prezzi stabili o delta documentato |
| **Stop conditions** | Formato file ambiguo senza specifica |
| **Evidenza privacy-safe** | Conteggi pre/post; nessun path file reale utente |
| **Stato** | **PLANNED / NOT RUN** |

### H85-11 — UX Release no-jargon + accessibility pass

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Card/summary/sheet sync comprensibili; Dynamic Type / VoiceOver su CTA critiche |
| **Dataset richiesto** | **H85DATA-SMALL** |
| **Preflight** | Elenco chiavi/copy da grep (futuro) |
| **Check atteso** | Assenza termini proibiti in Release; a11y senza troncamenti bloccanti |
| **Stop conditions** | Richiesta nuova UI fuori task |
| **Evidenza privacy-safe** | Screenshot oscurati |
| **Stato** | **PLANNED / NOT RUN** |

### H85-12 — Localizzazione completa IT/EN/ES/zh-Hans

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Parità stringhe percorsi sync + errori rilevanti |
| **Dataset richiesto** | Nessuno specifico |
| **Preflight** | `plutil` / inventory chiavi (execution futura) |
| **Check atteso** | Nessuna chiave mancante nei quattro file |
| **Stop conditions** | — |
| **Evidenza privacy-safe** | Esito tool + file coinvolti (no segreti) |
| **Stato** | **PLANNED / NOT RUN** |

### H85-13 — Privacy-safe observability / log redaction

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Definire/redigere log Debug vs Release; no leak barcode/listino/token |
| **Dataset richiesto** | **H85DATA-SMALL** |
| **Preflight** | Policy scritta H85 |
| **Check atteso** | Log campione senza PII; solo classi/conteggi |
| **Stop conditions** | Instrumentazione che richiede payload row-level in chiaro |
| **Evidenza privacy-safe** | Esempio log redatto |
| **Stato** | **PLANNED / NOT RUN** |

### H85-14 — Regression pack completo Supabase manual sync

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Elenco XCTest + smoke manuale minimo post-modifiche future |
| **Dataset richiesto** | Mix fake/sandbox da manifest H85 |
| **Preflight** | TASK-083 lezione: manifest completo prima di smoke dichiarato PASS |
| **Check atteso** | Tutti i test mirati TASK-078…082 in verde quando execution autorizzata |
| **Stop conditions** | Dipendenza da Supabase live senza consenso |
| **Evidenza privacy-safe** | Conteggio test PASS/FAIL; no backend dump |
| **Stato** | **PLANNED / NOT RUN** |

### H85-15 — Final readiness checklist 100%

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Chiudere la definizione roadmap «100%» nel MASTER-PLAN solo con **evidenza per voce** (PASS/PARTIAL/BLOCKED motivato) |
| **Dataset richiesto** | combinazione manifest H85 |
| **Preflight** | Review gap G1…G5 e stati NOT RUN residui |
| **Check atteso** | Tabella checklist ↔ evidenza; nessun claim “100%” senza riga evidenza |
| **Stop conditions** | Voce critica senza segnale misurabile |
| **Evidenza privacy-safe** | Indice documenti H85-* allegati |
| **Stato** | **PLANNED / NOT RUN** |

### H85-16 — UX/UI polish Release walkthrough iOS

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Validare in Release (o percorso equivalente documentato) il flusso operativo: **Home inventario** → import file → anteprima colonne (PreGenerate) → sessione **Generated** → ricerca/scan → modifica riga → tab **Database** → import analysis → export/share → **Opzioni** (incl. sync card dove previsto). Focus: chiarezza, feedback, coerenza Apple-native — **senza** copiare UI Android. |
| **Dataset richiesto** | **H85DATA-UX-FLOW** (fixture piccola ma completa, chiavi sandbox) |
| **Preflight** | Manifest UX-FLOW approvato; build identificata; nessun dato negozio reale |
| **Check atteso** | Ogni step attraversabile con esito documentato (PASS/PARTIAL/BLOCKED); screenshot oscurati per prove |
| **Stop conditions** | Scope creep o redesign non richiesto; necessità di dati reali |
| **Evidenza privacy-safe** | Elenco step + esiti; conteggi aggregati; nessun barcode/token reale |
| **Stato** | **PLANNED / NOT RUN** |

### H85-17 — Responsività UI e main-thread budget

| Campo | Valore |
|-------|--------|
| **Obiettivo** | Verificare che **import**, **export**, **preview cloud**, **apply** non blocchino la UI oltre i limiti seed: **primo feedback entro ~500 ms**; per operazioni **> ~2 s** messaggio di **fase** visibile; **tap duplicati** disabilitati su CTA lunghe; main-thread non saturo o documentato come PARTIAL con motivazione |
| **Dataset richiesto** | **H85DATA-SMALL** (smoke rapido) + **H85DATA-MEDIUM** / **H85DATA-LARGE** dove applicabile |
| **Preflight** | Strumento/timing definito in execution (es. osservazione manuale + note temporettica — **non** claim numerici finché non misurati) |
| **Check atteso** | Criteri **D85-15** e sezione «Soglie seed per futura execution» rispettati o PARTIAL motivato |
| **Stop conditions** | Tentativo di “fix” con sync background; assenza totale di feedback |
| **Evidenza privacy-safe** | Tempi indicativi range; fase UI mostrata; nessun payload |
| **Stato** | **PLANNED / NOT RUN** |

---

## Manifest hardening (futuro H85)

*Tutti **sandbox**; inventati; **nessun** dato negozio reale.*

| ID | Descrizione sintetica |
|----|------------------------|
| **H85DATA-SMALL** | Poche righe catalogo + prezzo singolo; smoke rapido UX/a11y |
| **H85DATA-MEDIUM** | Ordine ~10³ righe o intermedio replicabile su simulator |
| **H85DATA-LARGE** | Stress import/export e preview (soglia da definire in execution) |
| **H85DATA-PRICE-STRESS** | Molte righe `inventory_product_prices` / storico con effective_at controllati |
| **H85DATA-OUTBOX-PARTIAL** | Coda `sync_events` con mix inviato/in attesa/non registrabile senza payload reali |
| **H85DATA-CONFLICT** | Due modifiche catalogo con `updated_at` / baseline controllati (seed) |
| **H85DATA-OFFLINE** | Stessa base SMALL/MEDIUM con fasi offline certificate |
| **H85DATA-IMPORT-EXPORT** | Fixture Excel + round-trip export DB solo chiavi sandbox |
| **H85DATA-UX-FLOW** | Fixture **piccola ma completa** per attraversare **Home → import file → preview colonne → Generated → scan/ricerca → modifica riga → Database → import analysis → export/share** senza dati reali; include subset fornitori/categorie/prezzi coerente con chiavi sandbox |
| **H85DATA-ACCESSIBILITY** | SMALL con focus UI sync (opzionale, stesso seed SMALL) |

---

## Decisioni D85

| ID | Decisione |
|----|-----------|
| **D85-01** | Hardening **non** significa aggiungere sync automatica o background. |
| **D85-02** | **Manual-first** resta policy finché non esiste un task separato che autorizzi esplicitamente background/Realtime/worker. |
| **D85-03** | Performance su dataset grande richiede **soglie numeriche** (tempo/passo/cardinalità), non valutazioni soggettive. |
| **D85-04** | Ogni scenario non eseguito in esecuzione futura resta **NOT RUN** / **PLANNED** — nessun PASS implicito. |
| **D85-05** | Crash/recovery **non** può dipendere da cleanup distruttivo (truncate/delete/reset outbox non autorizzati come fix). |
| **D85-06** | **No-jargon Release** è requisito di produzione: testi visibili senza termini tecnici interni (`sync_events`, RPC, outbox in UI, ecc.). |
| **D85-07** | **Privacy-safe logging** obbligatorio: redazione default; nessuna evidenza con barcode/token/email/owner id reali. |
| **D85-08** | **ProductPrice current/previous** è area critica: voci checklist 100% restano PARTIAL finché G1/G4/G5 non hanno evidenze. |
| **D85-09** | Outbox **partial/dead/retry** deve comparire nel **summary utente** (Registrate / In attesa / Non registrabili), non solo in log. |
| **D85-10** | Se il gap richiede **backend/schema** (G3/G4), aprire **task separato** Supabase/backend — non patch iOS “tattica” nel perimetro H85. |
| **D85-11** | **TASK-085 planning non implementa patch** Swift/Kotlin/SQL/project/strings. |
| **D85-12** | Readiness **100%** richiede **evidenze** collegate alla checklist, non solo caselle compilate o testo generico. |
| **D85-13** | Piccoli **polish UI/UX** futuri sono **autorizzati** se migliorano **chiarezza**, **feedback**, **accessibilità** o **coerenza** con lo **stile iOS esistente** — non redesign non richiesto. |
| **D85-14** | In caso di **scelta UI/UX**, preferire la soluzione **più nativa iOS** e coerente con il resto dell’app; **evitare** porting **1:1** da Android (Android resta riferimento **funzionale**). L’agente decide autonomamente tra opzioni equivalenti e documenta la scelta in execution. |
| **D85-15** | Ogni **operazione lunga** deve avere **feedback visibile**; **progress** quando tecnicamente disponibile; **blocco tap duplicati** su CTA critiche; **CTA recovery** (annulla / riprova / ricontrollo) esplicita. |
| **D85-16** | Le **soglie performance** elencate in «Soglie seed per futura execution» sono **seed iniziali**, **non** claim PASS: vanno **confermate** in execution con **evidenze privacy-safe** (**D85-04**, **D85-07**). |
| **D85-17** | Futura execution **per tranche** consigliata: (1) **P0 misurabili** (manifest + formato evidenze); (2) **gap tecnici**; (3) **performance/recovery**; (4) **polish UI/UX** nativo iOS; (5) **checklist 100%** solo con evidenze. |

---

## Soglie seed per futura execution

*Valori **orientativi** per pianificare la misurazione; **nessun PASS** di prodotto finché non supportati da evidenze (**D85-16**).*

| Area | Soglia seed | Note |
|------|-------------|------|
| **Primo feedback UI** | Entro **circa 500 ms** dalla azione utente (tap su import, Controlla cloud, Conferma, ecc.) | Percepire “l’app ha ricevuto il comando”; ProgressView o stato equivalente |
| **Operazioni > ~2 s** | **Messaggio di fase** visibile (“Import in corso…”, “Analisi…”, ecc.) | Evitare UI apparentemente bloccata |
| **Tap duplicati** | **Disabilitare** ripetute attivazioni della stessa CTA mentre l’operazione è in corso | Ridurre doppie sottomissioni |
| **Import/export LARGE** | **Completamento** con successo **oppure** **stop controllato** con **errore chiaro** all’utente (no hang infinito, no silent fail) | Memoria: strategia chunking/streaming da validare |
| **Preview/apply MEDIUM/LARGE** | Summary `applied` / `skipped` / `blocked` coerente con il piano | Allineato TASK-078…082 |
| **Crash/kill recovery** | **Nessun cleanup distruttivo** come prerequisito alla ripresa (**D85-05**) | Utente rientra da stato sicuro e comprensibile |
| **UX no-jargon Release** | **Nessun** termine tecnico interno visibile (RPC, `sync_events`, outbox, ecc.) | **D85-06** |
| **Evidenze** | Solo **privacy-safe** — conteggi aggregati, screenshot oscurati | **D85-07** |

---

## Ordine consigliato di futura execution

1. **Manifest H85DATA** completi (incluso **H85DATA-UX-FLOW**) + **formato evidenze** condiviso tra executor/reviewer.
2. **Gap tecnici P0:** ProductPrice **remote id** iOS; **`updated_at` Android**; **tombstone/conflitto ProductPrice** (schema/policy); **import/export** e **current/previous** (G1…G5).
3. **Performance / recovery:** H85-01, H85-02, H85-05, H85-06, H85-17, memoria import.
4. **UX/UI polish nativo iOS:** H85-11, H85-16, micro-dettagli **D85-13 / D85-14** con note in handoff.
5. **Checklist «100%»** solo dopo **evidenze** per ogni voce critica — **H85-15**, **D85-12**.

Allineato a **D85-17**.

---

## Regole UI/UX per futura execution

*Si applicano **solo** dopo handoff a **EXECUTION** autorizzato; **TASK-085 resta planning-only** (**D85-11**).*

- Preferire **SwiftUI nativo**: `NavigationStack`, toolbar, `List`/`Form`, sheet, `confirmationDialog`, `alert`, `ProgressView`, **ShareLink**, **FileImporter**, **FileExporter** ove adatto al target OS.
- **Logica utile** ereditata da Android (validazioni, errori, ordine operazioni) **senza** replicare layout Material/pattern Android 1:1.
- **Azioni distruttive**: sempre **conferma chiara** (`confirmationDialog` / alert dedicato) con copy user-facing.
- **Schermate dense**: gerarchia visiva chiara — **titolo**, **stato**, **CTA primaria**, azioni secondarie.
- **Piccoli dettagli estetici** (spacing, simboli SF Symbol coerenti): l’agente può decidere **autonomamente** purché **documentato** nel handoff/PR (**D85-13 / D85-14**).
- **TASK-085** non modifica codice; queste regole sono **vincoli di design** per i task futuri.

---

## Stop conditions (future execution H85)

La futura execution H85 si ferma immediatamente se:

- Servono **dati negozio reali** non coperti da consenso.
- Serve **cleanup/reset/truncate/delete** per proseguire.
- **Schema Supabase** o contratto HistoryEntry **non chiari**.
- **Sessione / owner / RLS** non riproducibili o ambigui.
- Il runtime richiede **patch immediate** fuori dal task autorizzato.
- Uno scenario richiede **write remoto** non confermato dall’utente.
- Si tenta di usare **background sync** per risolvere un problema del flusso manuale.
- Si tenta di dichiarare **readiness** senza evidenze privacy-safe.

---

## Evidenze privacy-safe (formato)

Ogni evidenza futura deve riportare almeno:

1. **Scenario** H85-xx
2. **Dataset** (manifest H85DATA-*)
3. **Build** (Debug/Release, versione app, dispositivo/simulator tipo senza UDID sensibile se possibile)
4. **Tempo indicativo** (es. secondi o range)
5. **Memoria** se disponibile (es. footprint indicativo, senza dump heap)
6. **Conteggi aggregati** (righe, applied, skipped, blocked, …)
7. **Stato** `PASS` / `PARTIAL` / `BLOCKED` / `FAIL` / `NOT RUN`
8. **Screenshot** solo se **oscurati** (niente barcode/listino/token/email/owner id reale)
9. **Divieto** di incollare payload JSON, URL con segreti, o dump DB.

---

## Rischi (planning)

| ID | Rischio | Mitigazione documentale |
|----|---------|-------------------------|
| R85-01 | Ripetere errore TASK-083: manifest incompleto → smoke falso BLOCKED | Completare H85DATA-* prima di execution; gate preflight |
| R85-02 | Confondere planning con execution | D85-11 + handoff NON READY FOR EXECUTION |
| R85-03 | Soglie performance vaghe o confuse con claim PASS | **D85-03**, **D85-16** + tabella «Soglie seed» + evidenze in execution |
| R85-04 | Gap G1–G5 rimasti “testuali” senza task figli | Tabella follow-up + MASTER-PLAN backlog (solo dopo decisione utente) |
| R85-05 | Tentativo di introdurre auto-sync come “fix” performance | Stop conditions + D85-01–02 |
| R85-06 | Polish UI/UX senza principi → incoerenza cross-schermata | D85-13 / D85-14 + «Regole UI/UX» + documentazione in handoff |

---

## Planning (Claude) — sintesi

### Analisi

TASK-084 ha chiuso la parità **documentale** statica e il manifest M1…M17 senza runtime; TASK-083 ha dimostrato che **manifest incompleto** blocca smoke E2E. TASK-085 deve collegare performance, recovery, osservabilità e checklist 100% della roadmap senza aprire sync background e senza claim di parità runtime completa.

### Approccio proposto

1. Usare la matrice a **33 aree** come backbone dei criteri futuri.
2. Collegare ogni area critica a uno o più scenari **H85-01…H85-17** e manifest **H85DATA-*** (incluso **H85DATA-UX-FLOW**).
3. Instradare G1…G5 verso task futuri (iOS/Android/Supabase/test) invece di assorbirli in un unico mega-task.
4. Definire **formato evidenze**, **soglie seed**, **ordine tranche** (**D85-17**), **regole UI/UX** e stop conditions **prima** di qualsiasi execution.

### File da modificare (futura execution — non ora)

- Solo task/markdown e tracking; **nessun** file codice in TASK-085 PLANNING.

### Handoff → Planning review

- **Prossima fase:** PLANNING REVIEW (utente / Claude reviewer)
- **Prossimo agente:** revisore designato (es. Claude / Reviewer)
- **Azione consigliata:** leggere matrice (**33 aree**) + G1…G5 + **H85-01…H85-17** + **D85-01…D85-17** + «Soglie seed» + «Regole UI/UX»; approvare o richiedere raffinamento **solo su markdown**

---

## Criteri di accettazione planning

- [x] File TASK-085 creato (`docs/TASKS/TASK-085-production-ready-hardening-ios.md`).
- [x] MASTER-PLAN aggiornato con progetto ACTIVE e TASK-085 ACTIVE/PLANNING *(verificare coerenza se si modifica solo questo file)*.
- [x] Matrice hardening presente (**33 aree** minime).
- [x] Sezione «Integrazione review ChatGPT — ottimizzazioni planning» presente.
- [x] Gap TASK-084 instradati (G1…G5).
- [x] Scenari **H85-01…H85-17** definiti (**NOT RUN**).
- [x] Manifest hardening definito (H85DATA-*, incluso **H85DATA-UX-FLOW**).
- [x] Decisioni **D85-01…D85-17** presenti.
- [x] Sezione «Soglie seed per futura execution» presente.
- [x] Sezione «Ordine consigliato di futura execution» presente.
- [x] Sezione «Regole UI/UX per futura execution» presente.
- [x] Stop conditions presenti.
- [x] Evidenze privacy-safe definite.
- [x] Handoff chiaro (**READY FOR PLANNING REVIEW**; **NON READY FOR EXECUTION**; **TASK-085 NON DONE**; **nessun TASK-086**).
- [x] Nessun codice/runtime/write eseguito in questo turno *(perimetro planning-only)*.

---

## Check finali

| Check | Stato | Note |
|-------|-------|------|
| `git diff --check` | ✅ ESEGUITO (post-integrazione markdown) | PASS |
| `git status --short` | Da eseguire prima di commit | file `docs/TASKS/TASK-085-*.md` |
| `xcodebuild` | ⚠️ NON obbligatorio | Escluso dal perimetro TASK-085 planning |
| Runtime / Simulator | ⚠️ NON eseguito | Escluso |
| Write Supabase | ⚠️ NON eseguito | Escluso |

---

## Execution / Fix

### Execution Gate Summary — S85-A

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **TASK-085 completo** | **PARTIAL_READY** | Le slice tecniche successive dipendono da gap non risolti o da evidenze non ancora prodotte: ProductPrice remote id iOS, timestamp Android, policy tombstone ProductPrice, import/export current/previous, fixture runtime. |
| **S85-A — Manifest + evidence format** | **READY_FOR_EXECUTION** | Slice markdown-only: definisce formato, stati e blocchi senza patch Swift/Kotlin/SQL, senza runtime, senza write Supabase, senza cleanup e senza sync automatica/background. |

User override applicato: l'utente ha autorizzato l'EXECUTION di TASK-085 in slice piccole. Impatto sul tracking: il documento originale era **PLANNING / NON READY FOR EXECUTION**; questa execution e' limitata alla sola slice **S85-A** e ritorna a **REVIEW** per Claude.

### Slice S85-A — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Rendere operativo il gate per manifest H85DATA e formato evidenze, cosi' le slice successive non possano dichiarare PASS senza manifest, scenario, dataset, stato e prova privacy-safe. |
| **File previsti** | `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md` solo per stato/fase. |
| **File letti** | `docs/MASTER-PLAN.md`; `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/TASKS/TASK-084-android-ios-cross-platform-parity.md`; `docs/CODEX-EXECUTION-PROTOCOL.md`; `iOSMerchandiseControl/Models.swift`. |
| **Invarianti dati protetti** | Barcode sandbox unici; supplier/category coerenti; storico prezzi senza duplicati fantasma; current/previous spiegabile via `ProductPrice.effectiveAt`; nessun write ambiguo verso Supabase. |
| **Rischi** | Sovra-dichiarare manifest completo senza fixture reali; confondere formato pronto con runtime PASS; nascondere gap tecnici dietro `PARTIAL`. |
| **Test/check minimi** | Diff markdown statico; `git diff --check`; `git status --short`; build non necessaria se non vengono modificati file Swift/project. |
| **Motivo safe** | Patch documentale e di tracking; nessuna modifica app, nessun dato reale, nessun runtime, nessun write remoto, nessun cleanup distruttivo. |

### S85-A — Manifest H85DATA gate v0.1

Regola generale: ogni dataset H85DATA puo' essere usato in una slice runtime solo se esiste una riga manifest con **ID**, **origine**, **entita'**, **chiavi sandbox**, **ordine operazioni**, **normalizzazione**, **conteggi attesi**, **stato gate**, **evidenza richiesta**. Se manca una di queste voci, lo scenario resta **BLOCKED_MANIFEST** o **PARTIAL_READY**, non PASS.

| Dataset | Stato gate S85-A | Record minimi richiesti prima del runtime | Evidenza minima richiesta | Blocca |
|---------|------------------|-------------------------------------------|---------------------------|--------|
| **H85DATA-SMALL** | **PARTIAL_READY** | 1 supplier, 1 category, 2 prodotti barcode `H85SANDBOX-SMALL-*`, 1 prezzo purchase, 1 prezzo retail | Conteggi entita' locali/cloud e screenshot oscurato se UI | Runtime PASS finche' i record non sono materializzati |
| **H85DATA-MEDIUM** | **PARTIAL_READY** | Cardinalita' target circa 10^3 righe, subset prezzi controllato, nessun dato reale | Tempo indicativo + conteggi righe + summary apply/export | Performance claim finche' cardinalita' e fixture non sono congelate |
| **H85DATA-LARGE** | **PARTIAL_READY** | Cardinalita' superiore a MEDIUM, definita prima della run, file fixture riproducibile | Tempo/range, eventuale memoria indicativa, exit controllato | Claim performance LARGE se soglia o fixture mancano |
| **H85DATA-PRICE-STRESS** | **BLOCKED_TECHNICAL_GAP** | ProductPrice con `effective_at` vicini, duplicati logici, current/previous attesi | # storico, # duplicate skipped, # blocked, current/previous aggregato | S85-B e/o policy G4/G5 se serve remote id/tombstone |
| **H85DATA-OUTBOX-PARTIAL** | **PARTIAL_READY** | Mix attivita' registrabili / in attesa / non registrabili, owner sandbox | Conteggi summary Registrate/In attesa/Non registrabili | Runtime drain finche' outbox non e' seedata senza cleanup |
| **H85DATA-CONFLICT** | **BLOCKED_TECHNICAL_GAP** | Due writer sandbox con timestamp controllati, baseline stale riproducibile | Stato stale/block aggregato | Claim parita' conflitti finche' G2/G4 restano aperti |
| **H85DATA-OFFLINE** | **PARTIAL_READY** | Variante SMALL/MEDIUM con fase offline documentata | Stato rete on/off + azione CTA manuale, senza token | PASS se avviene write non manuale |
| **H85DATA-IMPORT-EXPORT** | **PARTIAL_READY** | Fixture Excel/export con header dichiarati, righe valide/errore, round-trip due passaggi | Conteggi pre/post prodotti/prezzi/errori | Claim round-trip finche' current/previous e old price restano parziali |
| **H85DATA-UX-FLOW** | **PARTIAL_READY** | Fixture piccola completa per Home -> import -> Generated -> Database -> export/share -> Opzioni | Elenco step con PASS/PARTIAL/BLOCKED e screenshot oscurati | UI PASS se uno step manca o usa dati reali |
| **H85DATA-ACCESSIBILITY** | **PARTIAL_READY** | SMALL con testi lunghi/localizzazioni e CTA critiche | Esito Dynamic Type/VoiceOver manuale o NOT RUN motivato | Claim a11y finche' verifica non eseguita |

Nessun dataset viene marcato **READY_FOR_RUNTIME** in S85-A: questa slice consegna il formato e il gate, non fixture reali ne' runtime PASS.

### S85-A — formato record manifest

```markdown
#### H85DATA-<NAME> / H85-M<NN>-<SHORT-ID>

- Stato gate: READY_FOR_RUNTIME / PARTIAL_READY / BLOCKED_MANIFEST / BLOCKED_TECHNICAL_GAP / NOT_RUN
- Scenario collegato: H85-xx
- Origine: ios_seed / android_reference / supabase_seed / excel_fixture / manual_ui
- Entita': product / supplier / category / product_price / sync_event / import_row / export_file / ui_step
- Business key sandbox: H85SANDBOX-...
- Barcode: inventato, univoco, non reale, oppure N/A motivato
- Supplier/category: nome sandbox + relazione attesa
- Prezzi: tipo, valore simbolico, effective_at esplicito, current/previous atteso
- Ordine operazioni: step numerati riproducibili
- Normalizzazione fissata: trim/case/decimali/timezone/header
- Conteggi attesi: righe create/update/skipped/blocked/error
- Stop condition specifica: cosa blocca la run
- Evidenza richiesta: STATIC / BUILD / SIM / MANUAL + privacy note
- Follow-up se PARTIAL/BLOCKED: iOS / Android / Supabase / manifest / evidenza
```

### S85-A — formato evidenza scenario

```markdown
### H85-xx — <titolo>

- Run ID: TASK-085_H85-xx_<dataset>_<YYYY-MM-DD>_<PASS|PARTIAL|BLOCKED|FAIL|NOT-RUN>
- Slice: S85-<lettera>
- Tipo verifica: STATIC / BUILD / SIM / MANUAL
- Build: Debug/Release, app version/build se disponibile, device/simulator senza UDID
- Dataset: H85DATA-...
- Manifest record usati: H85-M...
- Stato: PASS / PARTIAL / BLOCKED / FAIL / NOT RUN
- Gate pre-run: READY_FOR_RUNTIME / PARTIAL_READY / BLOCKED_...
- Tempo indicativo: secondi o range, oppure N/A motivato
- Memoria indicativa: se disponibile, senza dump heap
- Conteggi aggregati: prodotti, supplier, category, prezzi, applied, skipped, blocked, errori
- Cosa cambia per l'utente: sintesi user-facing
- Cosa non cambia funzionalmente: no auto-sync, no cleanup, no cambio API/schema, ecc.
- Invarianti dati verificati: barcode / supplier-category / storico prezzi / current-previous / write Supabase
- Evidenze privacy-safe: screenshot oscurati, log redatti, output tool aggregato
- Rischi residui:
- Follow-up candidate:
```

### S85-A — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Build compila (Xcode / BuildProject) | ⚠️ NON ESEGUIBILE | Slice markdown-only; nessun file Swift, project o build setting modificato. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO (STATIC) | Nessun file compilabile modificato; la slice non puo' introdurre warning Swift. |
| Modifiche coerenti con il planning | ✅ ESEGUITO (STATIC) | S85-A segue D85-04/D85-07/D85-12/D85-17 e l'ordine candidato autorizzato dall'utente. |
| Criteri di accettazione verificati | ✅ ESEGUITO (STATIC) | Formato manifest/evidenza definito; stati PARTIAL/BLOCKED preservati; nessun PASS runtime dichiarato. |
| No sync automatica/background | ✅ ESEGUITO (STATIC) | Nessuna modifica codice; nessun Timer/BGTask/Realtime/worker/polling. |
| No cleanup distruttivo | ✅ ESEGUITO (STATIC) | Nessun comando o procedura di truncate/delete/reset aggiunta o usata. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun whitespace error. |
| `git status --short` | ✅ ESEGUITO | `MM docs/MASTER-PLAN.md`; `AM docs/TASKS/TASK-085-production-ready-hardening-ios.md`. |
| Write Supabase | ⚠️ NON ESEGUIBILE | Nessun write richiesto o autorizzato per S85-A; Supabase non usato. |

---

## Review

### REVIEW completa post-execution — 2026-05-09

| Campo | Esito |
|-------|-------|
| **Verdetto review** | **PARTIAL_ACCEPTED / APPROVED_WITH_FIXES** |
| **Decisione task** | **DONE come hardening chiuso e documentato**, non come certificazione "production-ready 100%" |
| **Motivo chiusura** | Le patch principali sono coerenti, i check mirati iOS/Android passano, i dati `TASK085_*` sono isolati e i residui sono documentati come follow-up/gap di readiness prodotto. |
| **Override utente** | L'utente ha chiesto esplicitamente la review completa e ha autorizzato la chiusura DONE se i residui sono accettabili e ben documentati. |

#### Problemi trovati

1. **ProductPrice apply iOS: duplicati locali stesso key/stesso prezzo troppo permissivi.** Prima della review, due `ProductPrice` locali con stessa chiave logica e stesso prezzo canonico potevano essere trattati come `skippedExisting`, indebolendo l'invariante "no duplicate ghosts".
2. **ProductPrice apply iOS: duplicati remoti stesso key/stesso prezzo troppo permissivi.** Due righe remote con stesso prodotto/tipo/effective_at e stesso prezzo canonico non venivano bloccate come conflitto; questo rendeva ambigua l'identita' remota da linkare.
3. **ProductPrice post-push identity resta PARTIAL.** Il dry-run evita push duplicati e l'apply collega/inserisce `remoteID`, ma il push manuale release non persiste ancora il `remoteID` locale dopo insert remoto. La correzione completa richiede estendere il contratto del servizio push e il wiring con `ModelContext`, quindi non e' stata fatta come micro-fix.
4. **Supabase backend `updated_at` resta PARTIAL/BLOCKED_SCHEMA_DECISION.** La review ha confermato trigger tombstone ma non un trigger `set_updated_at`; dalle evidenze S85-ENV2 `updated_at` viene valorizzato su insert ma non avanza su update normale. Nessun DDL remoto applicato.
5. **Supabase review query finale PARTIAL.** Durante la review, alcune query read-only parallele hanno attivato un circuit breaker temporaneo del pooler Supabase ("too many authentication failures"). Dopo il primo schema/trigger check riuscito e il read-back prezzi `TASK085_*`, non sono state eseguite altre query remote per evitare stress sull'ambiente.

#### Fix applicati direttamente

1. `SupabaseProductPriceApplyService` ora blocca come conflitto i duplicati locali stessa chiave logica anche quando il prezzo canonico e' identico.
2. `SupabaseProductPriceApplyService` ora blocca come conflitto i duplicati remoti stessa chiave logica anche quando il prezzo canonico e' identico.
3. `SupabaseProductPriceApplyServiceTests` include regressioni per duplicato locale stesso prezzo e duplicato remoto stesso prezzo.

#### Cose approvate

- iOS `ProductPrice.remoteID` opzionale e' coerente con SwiftData e con il pattern gia' usato da `Product`/`Supplier`/`Category`; la migrazione resta lightweight perche' il campo e' opzionale.
- iOS apply/dry-run ProductPrice riduce il rischio di duplicati fantasma: inserisce o collega `remoteID` solo quando la corrispondenza e' non ambigua e blocca mismatch/conflitti.
- Android `updated_at` parity lato app e' implementata in modo idiomatico Room: DTO catalogo, remote refs, DAO/repository, migration 15->16 e schema `16.json` propagano `remoteUpdatedAt`.
- Import/export current/previous iOS e' additivo: `oldPurchasePrice`/`oldRetailPrice` sono esportati senza rompere import esistenti e senza ridisegnare il formato.
- Nessuna sync automatica/background, nessun Timer/BGTask/Realtime/polling/worker, nessun cleanup distruttivo e nessun DDL remoto sono stati introdotti.

#### Test/check review

| Area | Esito | Evidenza |
|------|-------|----------|
| **iOS git** | ✅ ESEGUITO | `git diff --check` PASS; `git status --short` controllato. |
| **iOS XCTest mirati** | ✅ ESEGUITO | ProductPrice apply/dry-run/manual push + remote preview tests PASS su iPhone 16e iOS 26.2 dopo fix review. |
| **Android git** | ✅ ESEGUITO | `git diff --check` PASS; `git status --short` controllato; `gradle/libs.versions.toml` dirty preesistente/out-of-scope. |
| **Android unit mirati** | ✅ ESEGUITO | `testDebugUnitTest` mirato su migration/repository/round-trip PASS. |
| **Android build** | ✅ ESEGUITO | `assembleDebug` PASS con JBR Android Studio; warning AGP/Kotlin preesistenti. |
| **Android emulator** | ✅ ESEGUITO | AVD `Medium_Phone_API_35` avviato headless; APK debug installato; `.MainActivity` avviata con `Status: ok`; processo attivo; nessun crash fatale nei log recenti; emulator chiuso. |
| **Supabase/Palmbase** | ⚠️ PARTIAL | Read-only trigger check e read-back prezzi `TASK085_*` completati; query successive fermate dopo circuit breaker temporaneo del pooler. Nessun write/DDL/delete in review. |

#### Dati TASK085

- **Creati in execution:** supplier `TASK085_SUPPLIER_20260509T030056Z`; category `TASK085_CATEGORY_20260509T030056Z`; product barcode `TASK085_BARCODE_20260509T030056Z`; 4 ProductPrice purchase/retail current/previous con source `TASK085_SEED_20260509T030056Z`.
- **Puliti:** nessuno.
- **Lasciati:** tutti i record `TASK085_*` creati in execution, per evidenza e per evitare cleanup FK/RLS non necessario durante una review con pooler temporaneamente bloccante.

#### Rischi residui accettati per chiusura task

- Non e' chiuso il claim production-ready completo: runtime auth cross-platform Android -> Supabase -> iOS e iOS -> Supabase -> Android resta PARTIAL.
- Backend `updated_at` richiede decisione schema/policy separata prima di dichiarare stale/conflict parity PASS.
- ProductPrice post-push identity richiede una patch dedicata se si vuole persistere subito il remote row id dopo push manuale.
- Benchmark grande dataset e round-trip runtime app-file-app restano follow-up, non PASS.

---

## Handoff

- **CHIUSURA REVIEW:** TASK-085 chiuso **DONE / PARTIAL_ACCEPTED** su review post-execution e override utente.
- **Non e' un claim production-ready 100%:** i gap runtime/backend/performance restano documentati e tracciati come follow-up.
- **D85-01...D85-17** presenti nel documento.
- **H85-01...H85-17** definiti; gli scenari runtime non provati restano **PARTIAL / NOT RUN** dove indicato.
- **Nessun TASK-086 automatico** aperto.
- **Nessun DDL remoto, cleanup distruttivo o sync automatica/background** introdotti da TASK-085.

## Handoff post-execution — S85-A

- **Prossima fase:** REVIEW
- **Prossimo responsabile:** Claude / Reviewer
- **Slice completata:** S85-A — Manifest + evidence format
- **File modificati:** `docs/TASKS/TASK-085-production-ready-hardening-ios.md`, `docs/MASTER-PLAN.md`
- **Test/check:** `git diff --check` PASS; `git status --short` = `MM docs/MASTER-PLAN.md`, `AM docs/TASKS/TASK-085-production-ready-hardening-ios.md`; build non necessaria per slice markdown-only
- **Esito:** formato manifest/evidenza pronto per review; nessun dataset runtime marcato READY_FOR_RUNTIME; nessun PASS di prodotto dichiarato
- **Blocker:** le slice tecniche restano non avviate; H85DATA reali non materializzati; S85-B/G1 resta prossimo gate tecnico per ProductPrice identity iOS
- **Prossima slice consigliata:** S85-B — ProductPrice identity iOS, solo dopo review positiva di S85-A
- **TASK-085 NON DONE**

## Handoff post-execution — S85-B

### Execution Gate Summary — S85-B

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **TASK-085 completo** | **PARTIAL_READY** | Restano gap P0 non chiusi: Android `updated_at`, import/export current/previous, performance/recovery runtime, UX polish, checklist finale. |
| **S85-B — ProductPrice identity iOS** | **PARTIAL_READY sicuro / EXECUTED** | Il gap iOS `ProductPrice.remoteID` e' stato ridotto con patch SwiftData opzionale e test mirati. Non viene dichiarato PASS completo per l'identita' post-push manuale e per assenza di vincolo unique SwiftData su `remoteID`. |

### Slice S85-B — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Chiudere o ridurre il gap `ProductPrice` remote row identity su iOS, evitando duplicati fantasma e push duplicati per righe gia' collegate. |
| **File letti** | `docs/MASTER-PLAN.md`; `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `iOSMerchandiseControl/Models.swift`; servizi iOS `SupabaseProductPriceApplyService`, `SupabaseProductPricePreviewService`, `SupabaseProductPricePushDryRunService`, `SupabaseProductPriceManualPushService`, `SupabaseManualSyncReleaseFactory`, `ProductPriceManualPushDebugViewModel`, `OptionsView`; test ProductPrice apply/push/manual; Android read-only `ProductPriceRemoteRef`, `ProductPriceRemoteRefDao`, `InventoryRepository`, `InventoryCatalogRemoteRows`; Supabase locale read-only migration `inventory_product_prices`. |
| **File modificati previsti** | `iOSMerchandiseControl/Models.swift`; `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`; `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`; test mirati ProductPrice; tracking markdown. |
| **Invarianti dati protetti** | Barcode unico invariato; supplier/category non toccati; storico prezzi senza duplicati fantasma; `current/previous` resta spiegabile via storico/effectiveAt; nessun write ambiguo verso Supabase; nessun cleanup distruttivo. |
| **Rischi** | Migrazione SwiftData leggera per nuovo campo opzionale; identita' post-push manuale non persistita nella stessa patch; nessun vincolo unique SwiftData su `remoteID`; runtime con store esistente non verificato su dataset reale. |
| **Test/check minimi** | `git diff --check`; `git status --short`; XCTest mirati apply/dry-run ProductPrice; nessun write Supabase; Android/Supabase solo lettura. |
| **Motivo safe** | Patch limitata a identita' opzionale e dedupe ProductPrice; link remote id solo quando esiste una riga locale esatta e non ambigua; mismatch `remoteID` blocca come conflitto; nessuna modifica prezzo/categoria/supplier, nessuna cancellazione, nessun push remoto. |

### S85-B — modifiche execution

- Aggiunto `ProductPrice.remoteID: UUID?` opzionale su iOS, allineato al `id` remoto di `inventory_product_prices`.
- `SupabaseProductPriceApplyService` ora:
  - crea nuovi `ProductPrice` con `remoteID` della riga remota;
  - collega una riga locale esistente e non ambigua allo stesso remote row id senza creare duplicati;
  - blocca conflitti se una riga locale ha gia' un `remoteID` diverso;
  - considera la verifica post-apply completa solo se non restano insert o link identity da applicare.
- `SupabaseProductPricePushDryRunService` esclude dal push candidate le righe locali `ProductPrice` gia' collegate a un `remoteID`.
- Aggiunti/aggiornati test mirati per insert con remote id, link existing senza duplicato e skip push di righe gia' linked.

### S85-B — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Build compila (Xcode / BuildProject) | ✅ ESEGUITO | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests` PASS. Primo tentativo senza `OS=26.2` fallito per destinazione simulatore ambigua, poi corretto. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO (BUILD/STATIC) | Nessun warning nei file ProductPrice modificati osservato nel test mirato; warning/tooling AppIntents e warning preesistenti fuori slice non trattati. |
| Modifiche coerenti con il planning | ✅ ESEGUITO (STATIC) | S85-B riduce G1 senza Android code, senza SQL/backend live, senza auto-sync/background e senza cleanup. |
| Criteri di accettazione verificati | ✅ ESEGUITO (TEST/STATIC) | Test ProductPrice apply/dry-run PASS; identita' post-push manuale resta PARTIAL documentato. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun whitespace error. |
| `git status --short` | ✅ ESEGUITO | File Swift/test ProductPrice modificati piu' tracking markdown TASK-085/MASTER-PLAN. |
| Write Supabase | ⚠️ NON ESEGUIBILE | Nessun write Supabase richiesto o autorizzato; schema locale letto solo in read-only. |
| Android | ✅ ESEGUITO (STATIC READ-ONLY) | Android usato solo come confronto funzionale `ProductPriceRemoteRef`; nessuna modifica Kotlin. |

### S85-B — handoff breve

- **Slice:** S85-B — ProductPrice identity iOS
- **Gate iniziale:** PARTIAL_READY sicuro
- **Esito:** **PARTIAL** — gap iOS ridotto e testato; non chiuso al 100% per identity post-push manuale e vincolo unique non introdotto.
- **File letti:** task/MASTER, modelli e servizi ProductPrice iOS, test ProductPrice, riferimenti Android read-only, migration Supabase locale `inventory_product_prices`.
- **File modificati:** `iOSMerchandiseControl/Models.swift`; `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`; `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`; `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`; `iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests.swift`; `iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests.swift`; `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **Cosa cambia per l'utente:** meno rischio di duplicare righe storico prezzo gia' presenti dal cloud; prezzi gia' collegati al cloud non vengono riproposti come nuovi push.
- **Cosa non cambia:** nessuna sync automatica/background; nessun write remoto; nessuna modifica UI; nessuna modifica Supabase/Android; current/previous price non ridisegnati.
- **Check eseguiti:** `git diff --check` PASS; `git status --short`; XCTest mirati ProductPrice apply/dry-run PASS su iPhone 16e iOS 26.2.
- **Rischi rimasti:** SwiftData migration reale su store utente non provata; post-push manuale non persiste ancora il remote row id appena creato; uniqueness `remoteID` non enforced a livello modello; ProductPrice tombstone/update policy resta gap G4.
- **Prossima slice:** S85-C — Android timestamp parity, read-only e con stop se serve patch Kotlin reale.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-C

### Execution Gate Summary — S85-C

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **TASK-085 completo** | **PARTIAL_READY** | Restano slice S85-D…S85-G non eseguite e gap critici non chiusi. |
| **S85-C — Android timestamp parity** | **BLOCKED_BY_ANDROID_TASK** | Supabase espone `updated_at` per catalogo e iOS lo decodifica/propaga come `remoteUpdatedAt`; Android, nel riferimento read-only, non modella `updated_at` nei row catalogo e per chiudere la parita' serve patch Kotlin reale fuori repo target. |

### Slice S85-C — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Verificare read-only dove Android legge `updated_at` e confrontare il contratto con iOS `remoteUpdatedAt`, senza modificare Android. |
| **File letti** | iOS `SupabaseInventoryDTOs.swift`, `SupabaseInventoryService.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`; Android read-only `InventoryCatalogRemoteRows.kt`, `SupabaseCatalogRemoteDataSource.kt`, `InventoryRemoteFetchSupport.kt`, `InventoryRepository.kt`; Supabase locale read-only `20260417120000_task013_inventory_catalog_rls.sql`. |
| **File modificati previsti** | Solo tracking markdown (`docs/TASKS/TASK-085-production-ready-hardening-ios.md`, `docs/MASTER-PLAN.md`). |
| **Invarianti dati protetti** | Nessun dato locale/remoto mutato; nessun write Supabase; nessuna modifica Android; barcode/supplier/category/storico prezzi non toccati. |
| **Rischi** | Claim falso di parita' timestamp se il gap viene solo documentato; possibile divergenza stale/conflict cross-client finche' Android non propaga `updated_at`. |
| **Test/check minimi** | Verifica statica read-only; `git diff --check`; `git status --short`; build non necessaria per slice markdown-only. |
| **Motivo safe** | Nessuna patch codice Android/iOS/SQL; la slice registra il blocco invece di inventare PASS o modificare fuori perimetro. |

### S85-C — risultato verifica read-only

- **Supabase locale:** `inventory_suppliers`, `inventory_categories`, `inventory_products` hanno `updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())`.
- **iOS:** `RemoteInventorySupplierRow`, `RemoteInventoryCategoryRow`, `RemoteInventoryProductRow` decodificano `updated_at`; `SupabasePullPreviewService` passa il valore a `SyncPreviewProductApplyPayload.remoteUpdatedAt`, `supplierRemoteUpdatedAt`, `categoryRemoteUpdatedAt`; `SupabasePullApplyService` aggiorna i campi `remoteUpdatedAt` locali.
- **Android riferimento:** `InventorySupplierRow`, `InventoryCategoryRow`, `InventoryProductRow` non hanno `updatedAt`; `SupabaseCatalogRemoteDataSource` fetch-a le righe catalogo tramite `fetchInventoryTableAllPagesOrderedById`, ma il DTO non conserva `updated_at`; il pull applica fingerprint payload e revisioni locali. Il codice include anche audit string `products_updated_at_untrusted`.
- **Conclusione:** la parita' timestamp catalogo resta **BLOCKED_BY_ANDROID_TASK**. Non e' corretto dichiarare PASS da iOS; serve task Android dedicato per modellare/propagare `updated_at` e poi evidenza runtime/parity.

### S85-C — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Build compila (Xcode / BuildProject) | ⚠️ NON ESEGUIBILE | Slice markdown/read-only; nessun file Swift/Kotlin/SQL modificato per S85-C. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO (STATIC) | Nessun file compilabile modificato in S85-C. |
| Modifiche coerenti con il planning | ✅ ESEGUITO (STATIC) | S85-C usa Android solo come riferimento read-only e registra il blocco senza patch Kotlin. |
| Criteri di accettazione verificati | ✅ ESEGUITO (STATIC) | Mapping iOS/Supabase/Android verificato; requisito chiuso come BLOCKED_BY_ANDROID_TASK, non PASS. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun whitespace error. |
| `git status --short` | ✅ ESEGUITO | Tracking markdown + file Swift/test S85-B ancora modificati: `MM docs/MASTER-PLAN.md`, `AM docs/TASKS/TASK-085-production-ready-hardening-ios.md`, file ProductPrice iOS/test. |
| Write Supabase | ⚠️ NON ESEGUIBILE | Nessun write Supabase richiesto o autorizzato; schema locale letto solo in read-only. |
| Android | ✅ ESEGUITO (STATIC READ-ONLY) | Nessuna modifica Kotlin; patch Android necessaria solo come follow-up separato. |

### S85-C — handoff breve

- **Slice:** S85-C — Android timestamp parity
- **Gate iniziale:** PARTIAL_READY
- **Esito:** **BLOCKED_BY_ANDROID_TASK**
- **File letti:** iOS DTO/service/preview/apply timestamp; Android row/data source/repository/fetch support; Supabase catalog migration.
- **File modificati:** `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **Cosa cambia per l'utente:** nulla nell'app; viene evitato un claim falso di parita' conflitti/timestamp cross-client.
- **Cosa non cambia:** nessun Android/Kotlin reale modificato; nessun Swift per S85-C; nessun Supabase write/schema; nessuna sync automatica/background.
- **Check eseguiti:** verifica statica read-only; `git diff --check` PASS; `git status --short` registrato.
- **Rischi rimasti:** finche' Android non decodifica/propaga `updated_at`, la stale/conflict parity Android ↔ iOS resta parziale; H85-09 non puo' diventare PASS pieno.
- **Prossima slice:** **S85-D sospesa** fino a decisione su task Android separato o override esplicito per procedere nonostante BLOCKED_BY_ANDROID_TASK.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-C2

### Execution Gate Summary — S85-C2

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **TASK-085 completo** | **PARTIAL_READY** | S85-A/B sono in REVIEW, S85-C2 riduce il blocker Android, ma restano collaudo Supabase reale, import/export current/previous, performance/recovery, UX polish e checklist finale. |
| **S85-C2 — Android timestamp parity execution** | **PARTIAL_READY sicuro / EXECUTED** | L'utente ha autorizzato override Android. La patch Kotlin e' piccola e confinata a DTO/ref/migration/test; il collaudo live Android ↔ Supabase ↔ iOS e' **BLOCKED_ENV** per ambiente Supabase non confermato. |

### Slice S85-C2 — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Chiudere il blocker Kotlin `BLOCKED_BY_ANDROID_TASK` aggiungendo decodifica/propagazione `updated_at` catalogo Android coerente con iOS `remoteUpdatedAt`; preparare collaudo cross-platform senza usare dati reali. |
| **File letti** | `docs/MASTER-PLAN.md`; questo task; iOS S85-B `Models.swift`, servizi/test ProductPrice; iOS DTO/pull preview/apply catalogo; Android `InventoryCatalogRemoteRows.kt`, `SupabaseCatalogRemoteDataSource.kt`, `InventoryRemoteFetchSupport.kt`, `InventoryRepository.kt`, remote ref DAO/entity, DAO catalogo, `AppDatabase.kt`, test repository/migration/export-import; Supabase locale migration catalogo e search schema `updated_at`. |
| **File modificati previsti** | Android DTO catalogo/ref/DAO/repository/migration/test + schema Room; tracking markdown. Nessuna patch Swift prevista per S85-C2 salvo test di regressione. |
| **Invarianti dati protetti** | Barcode unico non toccato; supplier/category remoti linkati senza merge ambiguo; storico prezzi non mutato; current/previous non ridisegnato; nessun write Supabase; nessun cleanup distruttivo; nessuna sync automatica/background. |
| **Rischi** | Migrazione Room su DB reali da verificare oltre unit test; `updated_at` backend potrebbe non cambiare su update normali senza trigger; collaudo live non sicuro finche' ambiente sandbox non e' confermato. |
| **Test/check minimi** | Android unit test repository/migration; Android build debug; XCTest mirati ProductPrice iOS; `git diff --check`; `git status --short`; Supabase collaudo solo se ambiente test/sandbox confermato. |
| **Motivo safe** | Patch additiva: nuovi campi nullable, migrazione ALTER TABLE add-column, DAO con `COALESCE` per non cancellare timestamp esistenti, test mirati; nessun dato remoto o schema Supabase mutato. |

### S85-C2 — modifiche effettuate

- Android `InventorySupplierRow`, `InventoryCategoryRow`, `InventoryProductRow` ora decodificano `updated_at` come `updatedAt`.
- Fingerprint inbound Android include `updatedAt`, cosi' un cambio timestamp remoto contribuisce alla revisione applicativa.
- `SupplierRemoteRef`, `CategoryRemoteRef`, `ProductRemoteRef` persistono `remoteUpdatedAt`; DAO e repository lo valorizzano quando le righe remote lo forniscono.
- Migrazione Room **15 → 16** aggiunge `remoteUpdatedAt TEXT` alle tre tabelle remote ref catalogo; generato schema Room `16.json`.
- Test Android aggiornati per verificare che bootstrap/pull memorizzi i timestamp catalogo e che la migrazione 15→16 aggiunga le colonne.
- Nessuna patch Swift nuova in S85-C2; rieseguiti test iOS ProductPrice per proteggere le modifiche S85-B.

### S85-C2 — collaudo Supabase richiesto

| Scenario | Stato | Evidenza / nota |
|----------|-------|-----------------|
| 1. Catalog timestamp parity | **PARTIAL** | STATIC/UNIT: Android decodifica e persiste `updated_at`; iOS decodifica `updated_at` come `remoteUpdatedAt`. LIVE: **BLOCKED_ENV**, Supabase locale non avviabile e ambiente remoto non confermato sandbox. |
| 2. Product update conflict/stale | **PARTIAL / BLOCKED_ENV** | Android ora conserva il timestamp remoto per stale/conflict parity, ma il live update cross-client non e' eseguito. Inoltre nello schema locale letto non e' stata trovata evidenza di trigger generale che aggiorni `updated_at` su update normali. |
| 3. ProductPrice identity | **PARTIAL** | iOS S85-B resta verificato da XCTest apply/dry-run: prezzi gia' linked via `remoteID` non vengono riproposti dal dry-run. Android mantiene strategia remote-ref separata per prezzi; live cross-platform non eseguito per BLOCKED_ENV. |
| 4. Supplier/category consistency | **PARTIAL** | Unit Android copre remote refs supplier/category con timestamp; nessun duplicato fantasma introdotto dalla patch. Live Android ↔ Supabase ↔ iOS non eseguito per BLOCKED_ENV. |
| 5. Import/export current/previous prep | **NOT RUN** | Preparazione rimandata a S85-D; la slice non ha ridisegnato formato import/export. |

### S85-C2 — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Android test mirati | ✅ ESEGUITO | `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest' --tests 'com.example.merchandisecontrolsplitview.data.AppDatabaseMigrationTest'` PASS. Primo tentativo senza Java runtime e' fallito per JDK non trovato; rerun con JBR Android Studio PASS. |
| Android build debug | ✅ ESEGUITO | `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew assembleDebug` PASS. Warning tooling/strip nativo e deprecation Gradle/AGP osservati, nessun errore build. |
| iOS test mirati | ✅ ESEGUITO | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests` PASS. |
| `git diff --check` iOS | ✅ ESEGUITO | PASS. |
| `git diff --check` Android | ✅ ESEGUITO | PASS. |
| `git status --short` iOS | ✅ ESEGUITO | Tracking markdown + file Swift/test S85-B ancora modificati. |
| `git status --short` Android | ✅ ESEGUITO | File Kotlin/test/schema Room S85-C2 modificati; `gradle/libs.versions.toml` era gia' modificato prima della slice e non e' stato toccato. |
| Collaudo Supabase live | ⚠️ NON ESEGUIBILE / BLOCKED_ENV | `supabase status --output json` fallisce per Docker daemon non raggiungibile; config iOS/Android punta allo stesso URL ma non localhost; chiavi iOS/Android diverse; ambiente sandbox/test non confermabile senza rischio. Nessun read/write live eseguito. |
| Write Supabase / schema deploy / cleanup | ✅ ESEGUITO (NEGATIVE CHECK) | Nessun write remoto, nessun deploy schema, nessun truncate/delete/reset, nessun dato reale usato. |

### S85-C2 — handoff breve

- **Slice:** S85-C2 — Android timestamp parity execution
- **Gate iniziale:** PARTIAL_READY con override utente per patch Android
- **Esito:** **PARTIAL** — blocker Kotlin ridotto/chiuso a livello codice e test; collaudo Supabase reale **BLOCKED_ENV**.
- **File letti:** TASK-085, MASTER-PLAN, iOS S85-B e DTO/pull/apply catalogo, Android DTO/data source/repository/DAO/ref/migration/test, Supabase locale schema catalogo.
- **File modificati:** Android `InventoryCatalogRemoteRows.kt`, `SupplierRemoteRef.kt`, `CategoryRemoteRef.kt`, `ProductRemoteRef.kt`, relativi DAO, `SupplierDao.kt`, `CategoryDao.kt`, `ProductDao.kt`, `InventoryRepository.kt`, `AppDatabase.kt`, test repository/migration/export-import, schema Room `16.json`; tracking `docs/TASKS/TASK-085-production-ready-hardening-ios.md`, `docs/MASTER-PLAN.md`.
- **Test/check eseguiti:** Android unit mirati PASS; Android `assembleDebug` PASS; iOS XCTest ProductPrice mirati PASS; `git diff --check` iOS/Android PASS; `git status --short` iOS/Android registrato.
- **Collaudo Supabase:** **BLOCKED_ENV / NON ESEGUIBILE** — Docker/Supabase locale non attivo, URL configurato non localhost, chiavi iOS/Android diverse; nessun accesso live eseguito.
- **Cosa cambia per utente:** su Android, dopo pull catalogo, il riferimento remoto puo' conservare il timestamp `updated_at`, migliorando la base tecnica per stale/conflict parity con iOS.
- **Cosa non cambia:** nessuna UI; nessuna sync automatica/background; nessun Timer/BGTask/Realtime/polling; nessun write Supabase; nessun cleanup distruttivo; nessun redesign import/export/current/previous.
- **Rischi rimasti:** live parity non provata; trigger backend `updated_at` su update normali non confermato; migrazione Room testata unitariamente ma non su dataset reale; ProductPrice identity resta PARTIAL per post-push manuale/unique constraint.
- **Prossima slice:** **S85-D sospesa** fino a conferma ambiente Supabase sandbox/local o override esplicito per procedere senza collaudo live.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-ENV

### Execution Gate Summary — S85-ENV

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **Remote Supabase/Palmbase access** | **PARTIAL_READY** | Accesso remoto SQL read-only disponibile via Supabase CLI linked project; iOS e Android puntano allo stesso project ref remoto. |
| **Mutazioni / collaudo live con seed** | **BLOCKED_DATA_RISK** | Il progetto remoto e' `merchandisecontrol-dev`, ma contiene un dataset ampio e production-like sotto un solo owner: 19.699 prodotti e 290.319 righe prezzo. Per regola utente, prima di insert/update/delete bisogna fermarsi se c'e' rischio dati reali. |
| **S85-D start** | **BLOCKED** | Non avviata: il collaudo remoto richiesto per proseguire non e' sicuro senza conferma esplicita che questo dataset dev puo' ricevere righe prefissate TASK085/H85/S85. |

### Slice S85-ENV — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Confermare ambiente remoto Supabase/Palmbase, URL/chiavi iOS/Android, schema catalogo/prezzi, RLS/owner, `updated_at`, e decidere se il runtime remoto e' sicuro per seed test. |
| **File letti** | `docs/MASTER-PLAN.md`; questo task; `/Users/minxiang/Desktop/MASTER-PLAN Android.md`; `/Users/minxiang/Desktop/MASTER_PLAN Supabase.md`; iOS `SupabaseConfig.plist` solo localmente senza stampare segreti; Android `local.properties` solo localmente senza stampare segreti; schema remoto via query read-only; Supabase locale migrations come riferimento. |
| **File modificati previsti** | Solo tracking markdown se il gate blocca. Nessuna patch Swift/Kotlin/SQL prima di ambiente runtime sicuro. |
| **Invarianti dati protetti** | Nessun dato reale letto in payload; nessun token stampato; nessun insert/update/delete; nessun truncate/drop/reset; nessun deploy schema; nessun cleanup; nessun seed remoto. |
| **Rischi** | Dataset remoto dev potrebbe contenere dati reali o copia production-like; mutazioni test anche prefissate potrebbero contaminare un owner reale. |
| **Test/check minimi** | Config compare privacy-safe; schema audit read-only; aggregate counts; RLS/policy/trigger audit; collision check prefissi test; `git diff --check`; `git status --short`. |
| **Motivo safe** | La slice si e' fermata prima di qualunque mutazione appena emerso il rischio dati. |

### S85-ENV — evidenze read-only

- **Project remoto:** Supabase CLI linked project `merchandisecontrol-dev`, ref mascherato `jpgo...kyvm`, stato ACTIVE_HEALTHY.
- **Config app:** iOS e Android puntano allo stesso project URL/ref. Le chiavi sono diverse per fingerprint/formato (iOS publishable key, Android key legacy/JWT-like), senza stampa di segreti.
- **REST anon:** inventory tables rispondono `permission denied` senza sessione autenticata, coerente con RLS; `history_entries` accessibile ma vuota; nessuna mutazione.
- **Schema remoto presente:** `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `sync_events`, `shared_sheet_sessions`, `history_entries`.
- **Colonne catalogo:** supplier/category/product hanno `owner_user_id`, `updated_at`, `deleted_at`; product prices hanno `id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `source`, `note`, `created_at`, ma non `updated_at`/`deleted_at`.
- **RLS:** inventory/sync/session tables hanno policy authenticated; catalog anon non leggibile.
- **`updated_at`:** esiste routine `set_updated_at`, ma sulle tabelle catalogo remote risultano solo trigger tombstone `inventory_*_block_post_tombstone_update`; nessun trigger `set_updated_at` collegato a `inventory_suppliers/categories/products` nel read-only audit.
- **Conteggi aggregati:** 1 auth user, 1 owner catalogo, 19.699 products, 81 suppliers, 44 categories, 290.319 product prices, 1.048 sync events, 13 shared sessions.
- **Collision prefissi test:** 0 righe prefissate `TASK085_`, `H85_`, `S85_` trovate nei controlli aggregati.

### S85-ENV — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Config iOS/Android | ✅ ESEGUITO | Stesso project URL/ref; segreti non stampati, solo fingerprint/lunghezze. |
| Schema audit remoto | ✅ ESEGUITO | Query `information_schema`, `pg_policies`, `pg_trigger` read-only via `supabase db query --linked`. |
| RLS/owner audit | ✅ ESEGUITO | Anon denied su inventory; policy authenticated presenti; 1 owner aggregato. |
| `updated_at` audit | ✅ ESEGUITO | Colonne presenti su catalogo; nessun trigger update normale collegato alle tabelle catalogo; test mutativo non eseguito per data risk. |
| Seed/update test row | ⚠️ NON ESEGUIBILE / BLOCKED_DATA_RISK | Dataset remoto ampio/production-like; regola utente impone stop prima di mutare se c'e' rischio dati reali. |
| Write Supabase / SQL mutativo | ✅ ESEGUITO (NEGATIVE CHECK) | Nessun insert/update/delete/DDL eseguito. |
| S85-D start | ❌ NON ESEGUITO | Fermato dal gate S85-ENV per rischio dati prima del collaudo remoto richiesto. |

### S85-ENV — handoff breve

- **Slice:** S85-ENV — Remote Supabase/Palmbase Environment Confirmation
- **Gate iniziale:** PARTIAL_READY con override remoto autorizzato
- **Esito:** **BLOCKED_DATA_RISK** — ambiente accessibile e schema verificato read-only, ma mutazioni/collaudo seed bloccati per dataset remoto production-like.
- **File letti:** TASK-085, MASTER-PLAN iOS, MASTER-PLAN Android, MASTER_PLAN Supabase, config iOS/Android, schema remoto read-only.
- **File modificati:** `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **SQL/Supabase:** solo query read-only; nessun write, nessun DDL, nessun cleanup.
- **Test iOS:** non eseguiti in S85-ENV; nessuna patch Swift.
- **Test Android:** non eseguiti in S85-ENV; nessuna patch Kotlin nuova.
- **Simulator/emulator:** non eseguito; bloccato prima del runtime mutativo.
- **Collaudo cross-platform:** **BLOCKED_DATA_RISK** prima di seed/update; schema/config parity verificata read-only.
- **Cosa cambia per utente:** nulla nell'app; il task evita contaminazione di un dataset remoto non confermato sandbox.
- **Cosa non cambia:** nessuna sync automatica/background; nessun Timer/BGTask/Realtime/polling; nessun dato remoto mutato; S85-D/E/F/G non avviate.
- **Rischi rimasti:** serve conferma esplicita che `merchandisecontrol-dev` con dataset 19.699/290.319 e unico owner e' sandbox e puo' ricevere righe test prefissate, oppure serve ambiente vuoto dedicato.
- **Prossima slice:** **S85-D bloccata** finche' non c'e' ambiente remoto sandbox confermato o dataset dedicato.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-ENV2

### Execution Gate Summary — S85-ENV2

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **Remote Supabase/Palmbase controlled seed** | **PARTIAL_READY** | L'utente ha autorizzato Opzione 2 su `merchandisecontrol-dev` production-like, solo righe isolate `TASK085_*`; seed/read/update controllati completati senza toccare dati reali. |
| **Runtime Android/iOS app auth** | **PARTIAL** | RLS nega correttamente REST anon; senza una sessione app autenticata accessibile da CLI/emulatore non posso dichiarare lettura runtime completa Android/iOS. |
| **Backend `updated_at` semantics** | **PARTIAL / GAP** | `updated_at` viene valorizzato in insert, ma non avanza su update normale della riga prodotto test; la parita' stale/conflict resta parziale anche con DTO iOS/Android corretti. |

### Slice S85-ENV2 — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Superare `BLOCKED_DATA_RISK` con test remoto non distruttivo su sole righe `TASK085_*`, confermare project ref/config/schema/RLS, creare seed minimo supplier/category/product/prices e verificare timestamp/coerenza. |
| **File letti** | `docs/MASTER-PLAN.md`; questo task; `/Users/minxiang/Desktop/MASTER-PLAN Android.md`; `/Users/minxiang/Desktop/MASTER_PLAN Supabase.md`; config iOS `SupabaseConfig.plist` senza segreti; Android `local.properties` senza segreti; schema remoto via query read-only. |
| **File modificati previsti** | Solo tracking markdown in questa mini-slice. |
| **Invarianti dati protetti** | Solo prefisso `TASK085_`; preflight collisioni a 0; nessun record reale modificato; nessun delete/truncate/drop/reset; nessun DDL; nessun token stampato; nessuna sync automatica/background. |
| **Rischi** | Dataset remoto dev e' production-like; owner unico; `updated_at` backend non avanza su update; runtime app richiede sessione autenticata. |
| **Test/check minimi** | Config compare privacy-safe; schema audit read-only; seed esatto `TASK085_*`; update solo su product creato; read-back aggregato; REST anon RLS; `adb devices`; `git diff --check`; `git status --short`. |
| **Motivo safe** | Le uniche mutazioni sono insert/update su righe create in questa sessione e prefissate `TASK085_`, con collision check preventivo e nessuna operazione distruttiva. |

### S85-ENV2 — evidenze remoto controllato

- **Project remoto:** `merchandisecontrol-dev`, ref mascherato `jpgo...kyvm`; iOS e Android puntano allo stesso project URL/ref.
- **Chiavi/config:** entrambe presenti e coerenti come project; fingerprint/lunghezze diverse, nessun segreto stampato.
- **Preflight collisioni:** 0 record `TASK085_` esistenti su supplier/category/product/price prima del seed.
- **Seed creato:** supplier `TASK085_SUPPLIER_20260509T030056Z`, category `TASK085_CATEGORY_20260509T030056Z`, product barcode `TASK085_BARCODE_20260509T030056Z`, product name `TASK085_PRODUCT_20260509T030056Z`, 4 righe price purchase/retail current/previous con `effective_at` controllato.
- **Read-back:** supplier/category/product coerenti; 2 purchase + 2 retail; `duplicate_count_same_effective=1` per ogni price; nessun duplicato fantasma rilevato nel seed.
- **`updated_at`:** insert valorizza `updated_at`; update controllato del solo product `TASK085_*` non ha avanzato `updated_at` (`updated_at_advanced=false`).
- **RLS:** REST anon su inventory product test restituisce `permission denied`; policy authenticated quindi attese per runtime app.
- **Simulator/emulator:** nessun iOS Simulator booted; `adb devices -l` non mostra device Android collegati/booted in quel momento.

### S85-ENV2 — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Config iOS/Android | ✅ ESEGUITO | Stesso project URL/ref; segreti non stampati. |
| Schema audit remoto | ✅ ESEGUITO | Tabelle inventory/sync/session/history verificate read-only; `inventory_product_prices.id` richiede UUID esplicito, rispettato nel seed. |
| Seed `TASK085_*` remoto | ✅ ESEGUITO | Insert controllati su supplier/category/product/4 prices, solo dopo collision preflight a 0. |
| Update `TASK085_*` remoto | ✅ ESEGUITO | Update solo su `second_product_name` della riga product creata in sessione; nessun dato reale toccato. |
| `updated_at` semantics | ⚠️ PARTIAL | `updated_at` presente su insert ma non avanzato su update normale; serve follow-up backend/additive trigger decision prima di PASS stale/conflict. |
| ProductPrice identity/dedupe seed | ✅ ESEGUITO | 4 price test, nessun duplicato per `(product,type,effective_at)`; source `TASK085_SEED_*`. |
| REST/RLS anon | ✅ ESEGUITO | Inventory REST anon risponde `permission denied`, coerente con RLS; runtime app richiede auth. |
| Android/iOS runtime read | ⚠️ PARTIAL | Non dichiarato PASS: nessun device Android/iOS booted con sessione autenticata verificabile da CLI in questa mini-slice. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| `git status --short` | ✅ ESEGUITO | Working tree iOS gia' modificato da S85-A/B/C2/tracking; nessun codice nuovo in S85-ENV2. |

### S85-ENV2 — handoff breve

- **Slice:** S85-ENV2 — Remote controlled test seed
- **Gate iniziale:** PARTIAL_READY con override esplicito utente su `merchandisecontrol-dev`
- **Esito:** **PARTIAL_READY / PARTIAL** — ambiente remoto testabile con righe `TASK085_*`; timestamp backend e runtime app auth restano parziali.
- **File letti:** TASK-085, MASTER-PLAN iOS, MASTER-PLAN Android, MASTER_PLAN Supabase, config iOS/Android, schema remoto.
- **File modificati:** `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **SQL/Supabase:** read-only audit; insert seed `TASK085_*`; update solo product test; nessun DDL; nessun delete/cleanup.
- **Test iOS:** non eseguito in mini-slice; nessuna patch Swift.
- **Test Android:** `adb devices -l` eseguito, nessun device booted; nessuna patch Kotlin.
- **Simulator/emulator:** iOS none booted; Android none listed.
- **Collaudo cross-platform:** Supabase seed/read PASS; runtime app Android/iOS resta PARTIAL per sessione autenticata/emulatori non disponibili al momento.
- **Cosa cambia per utente:** nulla nell'app; esiste fixture remota isolata per collaudi successivi.
- **Cosa non cambia:** nessuna sync automatica/background; nessun Timer/BGTask/Realtime/polling; nessun dato reale modificato; nessun cleanup distruttivo.
- **Rischi rimasti:** `updated_at` backend non avanza su update; righe test lasciate per evidenza e collaudo; runtime app auth non provata in questa mini-slice.
- **Prossima slice:** S85-D — Import/export current/previous.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-D

### Execution Gate Summary — S85-D

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **S85-D — Import/export current/previous** | **PARTIAL_READY / EXECUTED** | Android gia' esporta/importa current/previous su Products + PriceHistory; iOS aveva Products sheet senza old columns ma PriceHistory completo. Patch iOS piccola e compatibile applicata. |
| **Cross-platform runtime round-trip** | **PARTIAL** | Verificato schema/remote fixture e test Android import/export; non dichiarato PASS end-to-end app↔file↔app per assenza runtime autenticato/emulatori. |

### Slice S85-D — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Allineare export/import current/previous iOS ↔ Android ↔ Supabase senza redesign del formato Excel e senza perdita storico prezzi. |
| **File letti** | iOS `DatabaseView.swift`, `ProductImportCore.swift`, `Models.swift`; Android `DatabaseExportWriter.kt`, `ProductWithDetails.kt`, `ProductPriceSummary.kt`, `ImportAnalysis.kt`, `FullDbImportStreaming.kt`, test export/import; query Supabase su fixture `TASK085_*`. |
| **File modificati previsti** | Solo iOS `DatabaseView.swift` + tracking markdown. Android gia' coerente, nessuna patch Kotlin S85-D. |
| **Invarianti dati protetti** | Barcode unico non toccato; supplier/category esportati per nome come prima; storico ProductPrice non mutato; current/previous derivati dallo storico senza scrivere DB; nessun write ambiguo Supabase; nessun cleanup. |
| **Rischi** | Export Products cambia header aggiungendo due colonne; import iOS continua a usare PriceHistory sheet per storico completo e ignora old columns nei products-only import. |
| **Test/check minimi** | SQL read-back current/previous su `TASK085_*`; Android export/import test; iOS build/test mirati; `git diff --check`; `git status --short`. |
| **Motivo safe** | Patch additiva su export: colonne nuove `oldPurchasePrice`/`oldRetailPrice`, nomi gia' usati da Android, nessuna migration, nessun backend, nessun cambio di import destructive. |

### S85-D — modifiche effettuate

- iOS `Products` export ora include colonne additive `oldPurchasePrice` e `oldRetailPrice` sia in export prodotti sia in full database export.
- I valori current esportati usano l'ultimo `ProductPrice` per tipo se disponibile, con fallback ai campi snapshot del prodotto; i valori old usano il penultimo `effectiveAt` distinto, coerente con la logica Android `product_price_summary`.
- La sheet `PriceHistory` iOS resta invariata e continua a esportare `oldPrice`/`newPrice` per lo storico completo.
- Android non modificato in S85-D: `DatabaseExportWriter` aveva gia' colonne old e test round-trip.

### S85-D — evidenze current/previous remoto

- Fixture remota `TASK085_BARCODE_20260509T030056Z`:
  - current purchase `111.11`, previous purchase `101.01`;
  - current retail `222.22`, previous retail `202.02`;
  - supplier/category/product coerenti;
  - 4 price rows, nessun duplicato fantasma sul seed.

### S85-D — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| iOS build/test mirati | ✅ ESEGUITO | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests` PASS dopo fix compile. Primo tentativo fallito per `return` mancante nella closure `map`, corretto nella stessa slice. |
| Android export/import test | ✅ ESEGUITO | `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.util.DatabaseExportWriterTest' --tests 'com.example.merchandisecontrolsplitview.util.FullDbExportImportRoundTripTest'` PASS. Warning Gradle/AGP preesistenti. |
| Supabase current/previous read-back | ✅ ESEGUITO | Query read-only su fixture `TASK085_*`, campi current/previous coerenti con effective_at. |
| `git diff --check` iOS | ✅ ESEGUITO | PASS. |
| `git diff --check` Android | ✅ ESEGUITO | PASS. |
| `git status --short` iOS/Android | ✅ ESEGUITO | iOS: `DatabaseView.swift` + S85-B/tracking modificati; Android: file S85-C2 + schema 16, `gradle/libs.versions.toml` dirty preesistente. |
| Runtime file round-trip app↔app | ⚠️ PARTIAL | Non dichiarato PASS: niente sessione app autenticata/emulatore operativo per import/export manuale end-to-end. |

### S85-D — handoff breve

- **Slice:** S85-D — Import/export current/previous
- **Gate iniziale:** PARTIAL_READY
- **Esito:** **PARTIAL** — export iOS allineato in modo additivo; Android test PASS; round-trip runtime cross-platform resta non provato.
- **File letti:** iOS DatabaseView/ProductImportCore/Models; Android export/import/domain tests; Supabase fixture query.
- **File modificati:** `iOSMerchandiseControl/DatabaseView.swift`; `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **SQL/Supabase:** read-only su fixture `TASK085_*`; nessun write in S85-D.
- **Test iOS:** primo test build fallito e corretto; rerun PASS.
- **Test Android:** export/import round-trip tests PASS.
- **Simulator/emulator:** iOS Simulator usato da `xcodebuild test`; Android emulator non necessario per test JVM, non smoke UI.
- **Collaudo cross-platform:** schema/file mapping verificati; app runtime Android ↔ iOS via file resta PARTIAL.
- **Cosa cambia per utente:** export iOS mostra anche i prezzi precedenti nei prodotti, rendendo current/previous piu' spiegabili e vicini ad Android.
- **Cosa non cambia:** import iOS non viene ridisegnato; PriceHistory sheet resta il contratto storico completo; nessuna sync automatica/background; nessun dato reale toccato.
- **Rischi rimasti:** import products-only iOS ignora ancora old columns se manca PriceHistory; nessun smoke manuale file cross-platform completo; `updated_at` backend resta gap separato.
- **Prossima slice:** S85-E — Performance/recovery iOS + Android + Supabase.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-E

### Execution Gate Summary — S85-E

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **Performance/recovery iOS + Android + Supabase** | **PARTIAL_READY / EXECUTED** | Build/test/smoke principali eseguiti; runtime sync autenticata cross-platform resta non completamente verificabile. |
| **Patch consentite** | **SMALL PATCH APPLIED** | Aggiornato un test statico stale: TASK-071 vietava ancora il servizio ProductPrice manual push, ora intenzionale dalla factory Release post TASK-080/082. |

### Slice S85-E — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Verificare performance/recovery su flussi principali: feedback/retry/cancel iOS, build/test Android, emulator smoke, RLS/read-back Supabase su sole righe `TASK085_*`. |
| **File letti** | iOS `DatabaseView.swift`, `SupabaseManualSync*` tests/source; Android Gradle/app manifest; Supabase fixture SQL. |
| **File modificati previsti** | Solo test iOS se emerge falso negativo/stale; tracking markdown. Nessuna patch runtime Swift/Kotlin salvo fix piccolo. |
| **Invarianti dati protetti** | Nessun dato non `TASK085_*`; nessun delete/truncate/drop/reset; nessun background sync; nessun Timer/BGTask/polling; nessun write non isolato. |
| **Rischi** | Recovery live con auth/sessione reale non coperta; performance dataset grande non benchmarkata in modo quantitativo; emulator smoke non equivale a sync live autenticata. |
| **Test/check minimi** | iOS XCTest recovery/sync UI; Android `assembleDebug`; Android emulator install/launch smoke; Supabase read-only RLS/current fixture; `git diff --check`; `git status --short`. |
| **Motivo safe** | Verifiche non distruttive; emulator avviato/chiuso; nessun backend schema; test patch limita solo un divieto storico ormai superato. |

### S85-E — modifiche effettuate

- Aggiornato `SupabaseManualSyncRemotePreviewTests.testTask071ProductionSourcesAvoidForbiddenWriteAndAutomationScope`: rimosso il divieto su `SupabaseProductPriceManualPushService`, perche' la factory Release lo usa intenzionalmente dopo TASK-080/082. Restano vietati RPC/write diretti, `Timer`, `BGTask`, `Realtime`, `worker`, `polling`, `SupabaseClient`.
- Nessuna patch runtime iOS/Android per performance/recovery: i test esistenti coprono busy/concurrent runs, cancel, retryable network failure, partial outcomes e stale apply.

### S85-E — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| iOS XCTest recovery/sync | ✅ ESEGUITO | `xcodebuild test ... SupabaseManualSyncRemotePreviewTests, SupabaseManualSyncReleaseUITests, SupabaseManualSyncCoordinatorTests, SupabasePullApplyServiceTests/testApplyFailsPreviewStale...` PASS dopo patch test stale. Primo run fallito solo per guard TASK-071 obsoleta su `SupabaseProductPriceManualPushService`. |
| Android `assembleDebug` | ✅ ESEGUITO | `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew assembleDebug` PASS. Warning Gradle/AGP preesistenti. |
| Android emulator smoke | ✅ ESEGUITO | Avviato AVD `Medium_Phone_API_35`, installato `app-debug.apk`, lanciata `.MainActivity`, processo attivo e nessun `FATAL EXCEPTION`/`AndroidRuntime` nei log recenti; emulator chiuso con `adb emu kill`. |
| Supabase `TASK085_*` read-back/RLS | ✅ ESEGUITO | Query read-only su product fixture, `duplicate_rows=1` per price purchase current, 6 policy inventory rilevate; REST anon denial gia' verificato in S85-ENV2. |
| ProductPrice dedupe/identity | ✅ ESEGUITO (TEST/SQL) | iOS ProductPrice apply/dry-run tests PASS in S85-D; Supabase fixture non ha duplicati sul key test. |
| Runtime auth sync Android ↔ Supabase ↔ iOS | ⚠️ PARTIAL | Non dichiarato PASS: manca sessione autenticata app riusabile via CLI/UI per pull/push reale. |
| Performance dataset grande | ⚠️ PARTIAL | Build/test/smoke eseguiti; nessun benchmark quantitativo grande dataset in questa slice. |
| `git diff --check` iOS/Android | ✅ ESEGUITO | PASS. |
| `git status --short` iOS/Android | ✅ ESEGUITO | iOS: S85-B/D/E + tracking; Android: S85-C2 files + schema 16, `gradle/libs.versions.toml` dirty preesistente. |

### S85-E — handoff breve

- **Slice:** S85-E — Performance/recovery iOS + Android + Supabase
- **Gate iniziale:** PARTIAL_READY
- **Esito:** **PARTIAL** — build/test/smoke PASS; live sync autenticata e benchmark grande dataset restano PARTIAL.
- **File letti:** iOS sync/recovery tests/source, Android Gradle/manifest, Supabase fixture.
- **File modificati:** `iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests.swift`; `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **SQL/Supabase:** read-only su fixture `TASK085_*`; nessun write in S85-E.
- **Test iOS:** recovery/sync XCTest PASS dopo test stale fix.
- **Test Android:** `assembleDebug` PASS.
- **Simulator/emulator:** Android emulator smoke PASS; iOS Simulator usato da XCTest.
- **Collaudo cross-platform:** Supabase fixture + app smoke separati; Android↔Supabase↔iOS live auth sync resta PARTIAL.
- **Cosa cambia per utente:** nessun cambio runtime visibile; test suite non blocca piu' un servizio ProductPrice manuale ormai previsto.
- **Cosa non cambia:** nessuna sync automatica/background; nessun Timer/BGTask/Realtime/polling; nessun cleanup; nessun dato reale.
- **Rischi rimasti:** benchmark grande dataset non raccolti; auth UI/sessione non automatizzata; backend `updated_at` resta gap.
- **Prossima slice:** S85-F — UX polish iOS-native.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-F

### Execution Gate Summary — S85-F

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **UX polish iOS-native** | **PARTIAL_READY / REVIEW-ONLY** | Audit statico e test Release indicano gia' feedback, loading, cancel/retry e CTA disabled sui flussi principali; nessun polish runtime piccolo aggiuntivo e' emerso senza entrare in redesign/localization churn. |

### Slice S85-F — dichiarazione pre-modifica

| Voce | Contenuto |
|------|-----------|
| **Obiettivo** | Migliorare chiarezza/feedback/accessibilita' con micro-polish SwiftUI nativo solo se sicuro e coerente. |
| **File letti** | iOS `DatabaseView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncRemotePreview.swift`, test Release UI. |
| **File modificati previsti** | Nessuna patch runtime prevista dopo audit; solo tracking markdown. |
| **Invarianti dati protetti** | Nessun dato locale/remoto mutato; nessun sync/background; nessun import/export redesign; nessun testo tecnico nuovo in UI Release. |
| **Rischi** | Microcopy/localization churn potrebbe introdurre regressioni non necessarie; UI runtime non verificata con screenshot manuale completo. |
| **Test/check minimi** | Static audit; iOS XCTest Release/UI gia' PASS in S85-E; `git diff --check`; `git status --short`. |
| **Motivo safe** | Review-only: evita modifiche cosmetiche non necessarie e preserva stile SwiftUI nativo gia' testato. |

### S85-F — risultato audit UX

- `DatabaseView` ha overlay di progresso per full import con `ProgressView`, messaggio fase, annulla preparazione e guardia anti-doppio import tramite `importProgress.isRunning`.
- `OptionsView`/manual sync Release hanno CTA con `ProgressView`, azioni disabilitate durante stati loading/apply, cancel/retry e review sheet nativo.
- Test Release UI/remote preview in S85-E verificano copy senza jargon tecnico visibile e stati retry/cancel/partial non mappati a success.
- Il polish visibile gia' introdotto nella serie S85 resta S85-D: export iOS ora espone old price columns, migliorando chiarezza current/previous senza UI redesign.
- Nessuna patch SwiftUI aggiuntiva applicata: le alternative utili richiederebbero localizzazioni o redesign della sheet import/export, fuori perimetro di una micro-slice sicura.

### S85-F — checks eseguiti

| Check | Stato | Evidenza / nota |
|-------|-------|-----------------|
| Static UX audit | ✅ ESEGUITO | Progress/cancel/retry/disabled states trovati nei flussi import/sync principali. |
| iOS UI/recovery tests | ✅ ESEGUITO | S85-E XCTest Release/UI e coordinator PASS dopo patch test stale. |
| Patch runtime SwiftUI | ⚠️ NON ESEGUIBILE / NON NECESSARIA | Nessun micro-polish sicuro aggiuntivo oltre S85-D senza localizzazioni/redesign. |
| Android UI | ⚠️ NON ESEGUIBILE | Android e' riferimento funzionale, non target UX iOS; emulator smoke gia' PASS in S85-E. |
| `git diff --check` / `git status --short` | ✅ ESEGUITO | Eseguito dopo aggiornamenti di slice. |

### S85-F — handoff breve

- **Slice:** S85-F — UX polish iOS-native
- **Gate iniziale:** PARTIAL_READY
- **Esito:** **PARTIAL / REVIEW-ONLY** — nessuna patch runtime UI aggiuntiva; UX base verificata da audit/test.
- **File letti:** `DatabaseView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncRemotePreview.swift`, test Release UI.
- **File modificati:** `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`.
- **SQL/Supabase:** nessun SQL in S85-F.
- **Test iOS:** S85-E copre Release UI/recovery; nessun nuovo test necessario per slice review-only.
- **Test Android:** nessun nuovo test; S85-E emulator smoke PASS.
- **Simulator/emulator:** nessun nuovo smoke; nessuna UI runtime nuova da validare.
- **Collaudo cross-platform:** non applicabile a UX iOS-native; resta PARTIAL dal live auth sync.
- **Cosa cambia per utente:** nessun cambio runtime oltre S85-D; si evita un polish cosmetico non necessario.
- **Cosa non cambia:** stile SwiftUI nativo, CTA/progress/cancel/retry esistenti, nessun background sync.
- **Rischi rimasti:** screenshot/manual UI completo non eseguito; eventuali miglioramenti copy piu' ampi richiedono task/localization dedicati.
- **Prossima slice:** S85-G — Final readiness checklist.
- **TASK-085 NON DONE**

## Handoff post-execution — S85-G

### Execution Gate Summary — S85-G

| Gate | Stato | Motivazione |
|------|-------|-------------|
| **S85-G — Final readiness checklist** | **READY_FOR_EXECUTION / EXECUTED** | Le slice S85-A, S85-B, S85-C2, S85-ENV2, S85-D, S85-E e S85-F hanno handoff ed evidenze; resta da consolidare lo stato finale senza dichiarare DONE. |
| **TASK-085 globale** | **PARTIAL / READY_FOR_REVIEW** | Patch e test principali sono disponibili, ma rimangono gap critici: `updated_at` backend non avanza su update, sync runtime autenticata Android ↔ Supabase ↔ iOS non e' PASS, benchmark grande dataset non eseguito, ProductPrice identity post-push non completamente chiusa. |

### S85-G — checklist finale

| Area | Esito | Evidenze |
|------|-------|----------|
| **S85-A — Manifest + evidence format** | **PASS / REVIEW** | Formato manifest/evidenze H85DATA aggiunto; `git diff --check` PASS; nessun runtime claim. |
| **S85-B — ProductPrice identity iOS** | **PARTIAL** | `ProductPrice.remoteID` opzionale aggiunto; apply collega remote row id; dry-run non ripropone prezzi gia' linked; XCTest ProductPrice apply/dry-run PASS. Restano post-push identity e unique constraint da evidenziare. |
| **S85-C2 — Android timestamp parity execution** | **PARTIAL** | Android Room v16/DTO/ref persistono `remoteUpdatedAt`; test repository/migration e `assembleDebug` PASS. Backend remote `updated_at` non avanza su update normale, quindi stale/conflict parity resta parziale. |
| **S85-ENV2 — Remote controlled seed** | **PARTIAL_READY / PARTIAL** | Project `merchandisecontrol-dev` confermato; iOS/Android stesso project ref; seed `TASK085_*` creato e letto; RLS anon denial verificata; nessun dato reale modificato. Runtime app authenticated read/push/pull non dichiarato PASS. |
| **S85-D — Import/export current/previous** | **PARTIAL** | iOS export Products aggiunge `oldPurchasePrice`/`oldRetailPrice`; Android export/import tests PASS; fixture remote current/previous coerente. Round-trip runtime app↔file↔app resta PARTIAL. |
| **S85-E — Performance/recovery** | **PARTIAL** | iOS recovery/sync XCTest PASS; Android `assembleDebug` PASS; Android emulator install/launch smoke PASS; Supabase read-back PASS. Mancano benchmark grande dataset e sync live autenticata completa. |
| **S85-F — UX polish iOS-native** | **PARTIAL / REVIEW-ONLY** | Audit statico: progress/cancel/retry/disabled states presenti; nessun polish runtime aggiuntivo per evitare redesign/localization churn; test Release UI da S85-E PASS. |
| **S85-G — Final readiness checklist** | **PASS / REVIEW** | Checklist finale e tracking aggiornati; TASK-085 resta ACTIVE / REVIEW, non DONE. |

### Test finali consolidati

| Area | Esito | Evidenze |
|------|-------|----------|
| **iOS build/XCTest** | **PASS mirato** | ProductPrice apply/dry-run tests PASS; recovery/sync/Release UI/coordinator tests PASS su iPhone 16e iOS 26.2. Primo failure S85-D era compile `return` mancante, corretto; primo failure S85-E era test statico stale, corretto. |
| **Android unit/build** | **PASS mirato** | Unit mirati S85-C2/D PASS; `assembleDebug` PASS con JBR Android Studio. Warning Gradle/AGP considerati preesistenti/non bloccanti. |
| **Android emulator** | **PASS smoke launch** | AVD `Medium_Phone_API_35` avviato; APK debug installato; `.MainActivity` lanciata; nessun `FATAL EXCEPTION`/`AndroidRuntime` recente; emulator chiuso. |
| **Supabase/Palmbase** | **PARTIAL_READY** | Schema audit, RLS anon denial, seed/read/update isolati su `TASK085_*`; nessun DDL, nessun delete, nessun cleanup. |
| **Cross-platform** | **PARTIAL** | Config e schema condivisi verificati; Supabase fixture leggibile via query; Android/iOS code paths e tests allineati. Non PASS runtime completo Android → Supabase → iOS / iOS → Supabase → Android per assenza di sessione app autenticata automatizzata. |

### Dati test TASK085

| Voce | Stato |
|------|-------|
| **Creati** | Supplier `TASK085_SUPPLIER_20260509T030056Z`; category `TASK085_CATEGORY_20260509T030056Z`; product barcode `TASK085_BARCODE_20260509T030056Z`; 4 ProductPrice purchase/retail current/previous con source `TASK085_SEED_20260509T030056Z`. |
| **Puliti** | Nessuno. Cleanup non eseguito per preservare evidenza e per evitare rischi FK/RLS senza necessita'. |
| **Rimasti** | Tutti i record `TASK085_*` creati in questa sessione; sono isolati e documentati per review/collaudo successivo. |

### Rischi residui

- Backend catalogo: `updated_at` non avanza su update normale della riga product test; serve decisione Supabase additiva/trigger o policy alternativa prima di dichiarare stale/conflict PASS.
- ProductPrice: iOS identity e' ridotta ma non completa finche' non c'e' evidenza post-push manuale e/o vincolo unique/contract chiaro per evitare duplicati fantasma in tutte le condizioni.
- Runtime cross-platform: manca smoke autenticato completo Android ↔ Supabase ↔ iOS con pull/push reali delle app su account test.
- Import/export: iOS Products export ora include old prices, ma round-trip app↔file↔app su runtime resta PARTIAL; import products-only non usa old columns come fonte primaria di storico.
- Performance: non ci sono benchmark quantitativi su dataset grande/production-like; solo build/test/smoke controllati.
- UX: audit statico e test Release PASS, ma manca screenshot/manual UI completo su tutti i flussi lunghi.

### Cosa serve per DONE

1. Review Claude/utente delle patch S85-B/C2/D/E e della checklist S85-G.
2. Decisione backend su `updated_at` catalogo: trigger additivo o contratto alternativo documentato e testato.
3. Collaudo autenticato end-to-end con account test: Android → Supabase → iOS e iOS → Supabase → Android su sole righe `TASK085_*`.
4. Evidenza post-push ProductPrice identity/dedupe, inclusi current/previous e no duplicate ghosts.
5. Round-trip import/export runtime con file test e conteggi stabili.
6. Benchmark o smoke controllato dataset grande con soglie H85DATA, privacy-safe.
7. Cleanup sicuro o decisione esplicita di mantenere le fixture `TASK085_*`.

### S85-G — handoff breve

- **Slice:** S85-G — Final readiness checklist
- **Gate iniziale:** READY_FOR_EXECUTION
- **Esito:** **PASS per checklist / TASK-085 finale PARTIAL / READY_FOR_REVIEW**
- **File letti:** TASK-085, MASTER-PLAN iOS, MASTER-PLAN Android, MASTER_PLAN Supabase, handoff S85-A…F, status repo iOS/Android.
- **File modificati:** `docs/TASKS/TASK-085-production-ready-hardening-ios.md`; `docs/MASTER-PLAN.md`; `/Users/minxiang/Desktop/MASTER-PLAN Android.md`; `/Users/minxiang/Desktop/MASTER_PLAN Supabase.md`.
- **SQL/Supabase:** nessun SQL nuovo in S85-G; record `TASK085_*` restano come evidenza controllata.
- **Test iOS:** nessun nuovo test per docs-only; test mirati PASS da S85-D/E.
- **Test Android:** nessun nuovo test per docs-only; test/build/emulator PASS da S85-C2/D/E.
- **Simulator/emulator:** nessun nuovo smoke in S85-G.
- **Collaudo cross-platform:** consolidato come **PARTIAL**, non PASS.
- **Cosa cambia per utente:** TASK-085 ha una readiness checklist onesta e reviewabile; export iOS gia' migliorato da S85-D.
- **Cosa non cambia:** nessun DONE automatico, nessun production-ready 100%, nessuna sync automatica/background, nessun dato reale modificato.
- **Rischi rimasti:** vedi sezione rischi residui; i gap bloccano DONE ma non bloccano REVIEW.
- **Prossima slice:** Review Claude/utente; eventuale FIX mirato se richiesto.
- **TASK-085 NON DONE**
