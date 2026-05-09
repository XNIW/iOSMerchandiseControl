# TASK-085 — Hardening production-ready iOS / Supabase / cross-platform

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-085 |
| **Titolo** | Hardening production-ready iOS / Supabase / cross-platform |
| **File task** | `docs/TASKS/TASK-085-production-ready-hardening-ios.md` |
| **Stato** | ACTIVE |
| **Fase attuale** | PLANNING |
| **Responsabile attuale** | Claude / Planner |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 — planning iniziale (solo markdown) |
| **Ultimo agente** | Claude / Planner |
| **Repo iOS target** | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| **Repo Android riferimento** | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| **Supabase locale riferimento** | `/Users/minxiang/Desktop/MerchandiseControlSupabase` *(solo lettura se usato in fasi future)* |

---

## Dipendenze

- **Dipende da:** **TASK-084 DONE / Chiusura** — review documentale read-only P84-A/P84-B/P84-C; gap summary e routing approvati; **nessuna** equivalenza a parità runtime completa.
- **Considera TASK-083 DONE / Chiusura** come smoke end-to-end **bloccato da manifest incompleto** (preflight): S83-01 **BLOCKED**, S83-02…S83-06 **NOT RUN**; lezione H85 = manifest H85 completo prima di dichiarare PASS runtime.
- **TASK-078…TASK-082** = base implementativa sync mutativa Release iOS (pull apply, push catalogo, ProductPrice, drain outbox, conflitti/timestamp); TASK-085 **non le riapre** ma ne trae criteri di hardening e regression pack.
- **TASK-085 non riapre TASK-084** e non riesegue scenari P84 salvo override esplicito e gate separati.
- **TASK-085 non deve dichiarare** parità Android ↔ iOS runtime completa né smoke cross-platform PASS senza evidenze dedicate.

---

## Obiettivo

Definire — **solo in documentazione** — il piano di hardening production-ready per la roadmap Supabase iOS / cross-platform, includendo:

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

## Stato iniziale

- **TASK-084** è **DONE / Chiusura** come **review documentale read-only** (P84-A mapping statico, P84-B manifest M1…M17 documentale **NOT RUN**, P84-C schede **PLANNED / NOT RUN**).
- **TASK-084 non equivale** a parità runtime Android ↔ iOS completa, né a smoke cross-platform PASS.
- **Gap principali rimasti** (da TASK-084 gap summary, riportati qui come input al hardening, **non** corretti in questo task planning):
  - **ProductPrice `remoteID`** non persistito su iOS (`MISSING_IOS`) → asimmetria vs Android bridge; impatto su dedupe/push e diagnosi.
  - **`updated_at` catalogo** non decodificato nei row Android letti (`MISSING_ANDROID`) → iOS usa `remoteUpdatedAt` per stale/conflict; Android non espone lo stesso segnale nel modello row documentato.
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
- Scenari **H85-01…H85-15** tutti **PLANNED / NOT RUN**.
- Decisioni **D85-01…D85-12**.
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

*Stato attuale = noto da TASK-078…084 documentale / codice statico; runtime H85 = NOT RUN fino a execution futura.*

| # | Area | Stato attuale noto | Rischio production | Segnale/evidenza richiesta | Gap TASK-084 collegato | Priorità | Follow-up proposto |
|---|------|-------------------|---------------------|---------------------------|------------------------|----------|---------------------|
| 1 | Dataset grande import/export | iOS import/export funzionali; round-trip cross-client PARTIAL | Timeout OOM, UX blocco, file corrotti | Tempo/memoria/steps aggregati su H85DATA-LARGE; esito IMPORT/EXPORT | Export/import PARTIAL | P0 | Task iOS formato export + fixture H85; task manifest |
| 2 | Dataset grande sync preview | Preview/apply implementati Release; volume grande non evidenziato end-to-end | UI frozen, summary fuorviante, partial non chiaro | Profilo tempo su preview+sheet; conteggi skip/block | Performance OUT_OF_SCOPE_084 → H85 | P0 | Scenario H85-02 + soglie numeriche |
| 3 | Pull apply catalogo | TASK-078 DONE; guards stale/sessione TASK-082 | Apply errato se baseline/sessione incerta | PASS/PARTIAL con recheck obbligatorio | Catalog `updated_at` Android MISSING_ANDROID | P0 | H85-09 + task Android decode timestamp |
| 4 | Push catalogo | TASK-079 DONE | Partial write, UX non onesta | Summary post-push aggregato; nessun dump payload | — | P0 | H85-02, H85-08 |
| 5 | ProductPrice apply/push | TASK-080/082 DONE staticamente | Dedupe/conflict senza remote row id iOS | Conteggi applied/skipped/blocked; stress H85DATA-PRICE-STRESS | ProductPrice remote id MISSING_IOS | P0 | Task iOS persist remote id + H85-03 |
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

### G2 — updated_at catalogo Android non decodificato nei row letti

| Voce | Contenuto |
|------|-----------|
| **Origine** | TASK-084 — `InventoryProductRow` / supplier/category row senza `updated_at` mappato |
| **Impatto** | Policy stale/conflict cross-device può essere asimmetrica (iOS usa `remoteUpdatedAt`) |
| **Severità** | Media–alta per conflitti timestamp |
| **Task target futuro** | Task Android (decodifica e propagazione `updated_at` nel modello applicativo) |
| **Blocca readiness?** | **Parziale** — blocca claim di parità conflitti **simmetrici** fino a evidenza |

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

*Tutti gli scenari seguenti: **stato iniziale PLANNED / NOT RUN**; esecuzione solo in task futuro con override.*

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
| R85-03 | Soglie performance vaghe | D85-03 + numeri da fissare in EXECUTION |
| R85-04 | Gap G1–G5 rimasti “testuali” senza task figli | Tabella follow-up + MASTER-PLAN backlog (solo dopo decisione utente) |
| R85-05 | Tentativo di introdurre auto-sync come “fix” performance | Stop conditions + D85-01–02 |

---

## Planning (Claude) — sintesi

### Analisi

TASK-084 ha chiuso la parità **documentale** statica e il manifest M1…M17 senza runtime; TASK-083 ha dimostrato che **manifest incompleto** blocca smoke E2E. TASK-085 deve collegare performance, recovery, osservabilità e checklist 100% della roadmap senza aprire sync background e senza claim di parità runtime completa.

### Approccio proposto

1. Usare la matrice a 25 aree come backbone dei criteri futuri.  
2. Collegare ogni area critica a uno o più scenari H85 e manifest sandbox.  
3. Instradare G1…G5 verso task futuri (iOS/Android/Supabase/test) invece di assorbirli in un unico mega-task.  
4. Definire formato evidenze e stop conditions **prima** di qualsiasi execution.

### File da modificare (futura execution — non ora)

- Solo task/markdown e tracking; **nessun** file codice in TASK-085 PLANNING.

### Handoff → Planning review

- **Prossima fase:** PLANNING REVIEW (utente / Claude reviewer)  
- **Prossimo agente:** revisore designato (es. Claude / Reviewer)  
- **Azione consigliata:** leggere matrice + G1…G5 + H85-01…15; approvare o richiedere raffinamento **solo su markdown**  

---

## Criteri di accettazione planning

- [x] File TASK-085 creato (`docs/TASKS/TASK-085-production-ready-hardening-ios.md`).
- [x] MASTER-PLAN aggiornato con progetto ACTIVE e TASK-085 ACTIVE/PLANNING.
- [x] Matrice hardening presente (25 aree minime).
- [x] Gap TASK-084 instradati (G1…G5).
- [x] Scenari H85-01…H85-15 definiti (NOT RUN).
- [x] Manifest hardening definito (H85DATA-*).
- [x] Decisioni D85-01…D85-12 presenti.
- [x] Stop conditions presenti.
- [x] Evidenze privacy-safe definite.
- [x] Handoff chiaro.
- [x] Nessun codice/runtime/write eseguito in questo turno *(perimetro planning-only)*.

---

## Check finali

| Check | Stato | Note |
|-------|-------|------|
| `git diff --check` | ✅ ESEGUITO (post-modifica) | PASS se comando senza output |
| `git status --short` | ✅ ESEGUITO (post-modifica) | Elenco file modificati/aggiunti |
| `xcodebuild` | ⚠️ NON obbligatorio | Escluso dal perimetro TASK-085 planning |
| Runtime / Simulator | ⚠️ NON eseguito | Escluso |
| Write Supabase | ⚠️ NON eseguito | Escluso |

---

## Execution / Fix

*Vuoto — TASK-085 in **PLANNING**; nessuna execution autorizzata da questo documento da solo.*

---

## Review

*Non avviata — da compilare dopo planning review.*

---

## Handoff

- **READY FOR PLANNING REVIEW**  
- **NON READY FOR EXECUTION**  
- **TASK-085 NON DONE**  
- **Nessun task successivo aperto** (nessun TASK-086 automatico)
