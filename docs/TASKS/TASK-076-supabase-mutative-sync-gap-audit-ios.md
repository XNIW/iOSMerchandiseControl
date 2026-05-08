# TASK-076 — Gap audit finale sync mutativa Supabase iOS (solo planning)

## Informazioni generali
- **Task ID**: TASK-076
- **Titolo**: Gap audit finale sync mutativa Supabase iOS — inventario repo-grounded READY / PARTIAL / MISSING / BLOCKED
- **File task**: `docs/TASKS/TASK-076-supabase-mutative-sync-gap-audit-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Nessuno / Workspace passato a TASK-077
- **Data creazione**: 2026-05-08
- **Ultimo aggiornamento**: 2026-05-08 12:44 -0400 — review/chiusura documentale: TASK-076 chiuso come audit/planning, non come implementazione.
- **Ultimo agente che ha operato**: Codex / Executor+Closer

## Dipendenze
- **Dipende da**: TASK-072…TASK-075 **DONE / Chiusura** (perimetro UX read-only Release «Controlla cloud», wiring preview, summary volatile, smoke controllato) — stato **non** modificato da questo task
- **Sblocca**: TASK-077…TASK-085 sulla roadmap sync mutativa; TASK-077 e' stato avviato separatamente come UI-only non mutativo.

## Scopo
Produrre **solo documentazione**: un audit **repo-grounded** del codice Supabase/sync iOS esistente, classificando ogni area come **READY**, **PARTIAL**, **MISSING**, **BLOCKED** o **OUT OF SCOPE**, collegando i gap ai task futuri **TASK-077…TASK-085**, evidenziando rischi e micro-slice successive **senza implementazione Swift**.

## Contesto
Dopo TASK-075 la roadmap TASK-076→085 mira a sync mutativa **manuale** sicura da Release e a parita' cross-platform. Serve una fotografia tecnica aggiornata del repository iOS prima di autorizzare execution su conferma utente, apply/push mediati dal coordinator, outbox drain Release, ecc.

## Criteri di accettazione *(contratto planning-only)*
- [x] File `docs/TASKS/TASK-076-supabase-mutative-sync-gap-audit-ios.md` creato con tabella audit e collegamenti TASK-077…TASK-085
- [x] `docs/MASTER-PLAN.md` aggiornato: stato globale ACTIVE, TASK-076 ACTIVE/PLANNING, voce cronologica avvio, riga roadmap TASK-076 aggiornata *(eventuali note cronologiche di rifinitura planning senza cambio stato progetto globale)* 
- [x] Inventario tecnico derivato dalla **lettura** del codice iOS *(nessuna modifica sorgenti)*
- [x] Nessun claim «sync Release mutativa completa» senza riferimento a task/smoke futuri (**TASK-083** ecc.)
- [x] Anti-scope tecnico TASK-076 rispettato (nessun Swift, SQL live, drain/apply live)
- [x] **UX/UI Release contract** futuro definito + **Decisioni UX** (sheet leggera, `confirmationDialog` selettiva, card coerente `OptionsView`, CTA stabili)
- [x] **Stati user-facing futuri** tabellati (**idle…completed**) con vista utente / CTA / cosa non promettere
- [x] **Ordine operativo provvisorio** (#auth…#summary finale) documentato come **ipotesi di planning**, non implementation
- [x] Tabella decisioni **sistema automatico vs conferma utente vs differimento TASK-082/084**
- [x] **Definition of Done — planning TASK-076** compilata (`DoD-P1…P10`); planning review consumata con chiusura documentale; TASK-076 ora **DONE / Chiusura** e resta **NON READY FOR EXECUTION** come task
- [x] **Go / No-Go TASK-077**, struttura **sheet**, **regole visive**, **matrice TASK-084** minima, **crash/partial/recovery**, **anti-confusione CTA**

## Non incluso (anti-scope severo — vincoli espliciti)
- **Zero** modifiche a sorgenti **Swift**, `project.pbxproj`, **`Localizable`**
- **Zero** SQL, migration, `db push`, RLS/RPC/backend live
- **Zero** modifiche **Android**
- **Non** abilitare **`guidedManual`**, **non** impostare **`supportsGuidedManualSync = true`**
- **Non** introdurre sync automatica, `Timer`, `BGTask`, Realtime, worker, polling
- **Non** eseguire apply/push/drain live, reset/truncate/delete outbox
- **Non** promettere «sync completa» o equivalenza perfetta Android senza smoke/task dedicati (**TASK-084** / **TASK-083**)

---

## UX / UI Release contract — sync mutativa **futura** *(solo planning)*

Contratto destinato ai task **TASK-077 → TASK-085**: definisce cosa deve valere sulla **superficie Release** in `OptionsView`, senza impegnare l'implementazione in TASK-076.

### Flusso consigliato (macro-step)
1. **Controlla cloud** — prefetch read-only sicuro *(gia' parzialmente coperto dalla card attuale)*  
2. **Rivedi modifiche** — presentazione sintetica **in linguaggio naturale**, confrontabile con lo stato locale solo a livello comprensibile  
3. **Conferma** — utente conferma esplicitamente che accetta gli effetti dichiarati nello step 2  
4. **Applica / Invia** — mutazioni locali/remota **solo dopo** conferma (pull apply SwiftData, push catalogo/prezzi/drain nei task dedicati **TASK-078…TASK-081**)  
5. **Summary finale** — recap volatile/comprensibile: cosa e' stato controllato, applicato, inviato, saltato o non completato (**estensione naturale TASK-074**)

### Principi
- **Nessun dettaglio tecnico** in chiaro sulla card Release: niente stack trace, niente identificatori interni grezzi, niente campi tipo «phaseOutcome» leggibili come tali dall'utente.
- La UI deve restare **visivamente e strutturalmente coerente** con la scheda SwiftUI «Sincronizzazione cloud» gia' presente in `OptionsView` (gerarchie compatte, CTA chiare, `ProgressView` in running, badge accessibili dove gia' usati).

### Termini **vietati** come copy visibile all'utente in Release *(mapping interno OK in codice / log tecnici fuori vista)*
`outbox`, `RPC`, `DTO`, `payload`, `sync_events`, `drain`, `record_sync_event`, `baseline` (come parola sullo schermo; se serve concetto analogo usare lingua naturale tipo «allineamento dati dal cloud», «cronologia modifiche pendenti», «operazioni cloud in attesa» — soggetti a TASK-077 l10n).

---

## Decisioni UX provvisorie *(product-oriented)*

| ID | Decisione | Motivazione |
| --- | --- | --- |
| D76-UX-01 | Preferire una **sheet SwiftUI leggera** (`sheet`/`presentationDetents` compatibile) per **riepilogo + conferma** delle modifiche proposte | Evita stacking di bubble e alert frammentati; coerenza con linee guida Apple-like *(non implementativo)* |
| D76-UX-02 | Usare **`confirmationDialog`** solo per azioni **distruttive o ad alto rischio** (non per la revisione ordinaria delle differenze) | Riduce fatica decisionale TASK-077 |
| D76-UX-03 | **Non** introdurre una **nuova schermata / navigation stack pesante** finche' card `OptionsView` + sheet bastano ai contenuti TASK-078…080 | MVP navigazionale sicuro prima di refactoring tab |
| D76-UX-04 | Lessico CTA stabile e ristretto: **Controlla**, **Rivedi**, **Applica modifiche**, **Annulla**, **Riprova**, **Vedi riepilogo** (label finali in TASK-077 l10n IT/EN/ES/zh-Hans come oggi) | Riduce regressione UX e falsi percorsi |
| D76-UX-05 | Quando una scelta e' tecnica (**batch**, **ordering interno**, **retry idempotente**), il **sistema** sceglie il percorso **piu' sicuro** e **non** espone branching all'utente | Allineamento a «safe-by-default» TASK-068/TASK-063 |

---

## Stati user-facing **futuri** (Release) — tabella provvisoria

Stati nominali pensati **per progettazione TASK-066/072/077**, non ancora impegnativi nell'implementazione TASK-076.

| Stato tecnico nominale | Cosa vede l'utente *(indicativo)* | CTA primaria | CTA secondaria *(opz.)* | Cosa **non** deve promettere |
| --- | --- | --- | --- | --- |
| **idle** | Card pronta, spiegazione breve chiarezza sicurezza / niente invii automatici | Controlla | — | Tutto aggiornato / zero differenze |
| **checking** | «Controllo cloud in corso…» + spinner | *(disabilitato o Annulla se cancellabile)* | Annulla | Esito tecnico garantito mentre ancora incompleto |
| **reviewNeeded** | Sintesi non tecnica delle differenze o avviso che servono modifiche locali dopo il cloud | Rivedi / Vedi riepilogo | Controlla di nuovo | Applicazione implicita solo aprendo la sheet |
| **readyToApply** | Riassunto dopo revisione chiaro sul cosa accadra' se si procede | Applica modifiche | Annulla | Successo deterministico dopo «Applica» |
| **applying** | stato operativo (pull apply / push / invio modifiche…) con feedback di avanzamento alto livello | *(disabilitata o Annulla se supportato dalla fase sicura)* | Annulla | Completamento parziale presentato come completo |
| **partial** | «Alcuni passaggi non sono stati completati» + suggerimento Riprova o supporto **senza raw error** | Riprova / Vedi riepilogo | Controlla | Che il cloud e il device siano sempre allineati al 100% |
| **failed** | Messaggio sintetico + passo suggerito (es. ripetere dopo rete); niente jargon | Riprova | Controlla / Accedi *(se gate auth)* | Colpa utente implicita |
| **cancelled** | «Controllo annullato» *(pattern TASK-074/075 gia' osservabile)* | Riprova / Controlla | — | Dati modificati dall'annullo |
| **completed** | Summary finale sintetico (cosa OK / cosa no) | Controlla / fine flusso | Vedi riepilogo *(se disponibile stato precedente chiaro)* | «Tutto sincronizzato» se apply/push non eseguito o confermato |

---

## Stato attuale iOS (sintesi audit — lettura codice repo)

Il perimetro Release oggi e' **preview remota read-only** + **`dryRun`** nel `SupabaseManualSyncCoordinator`: auth/baseline/pending aggregati sono **reali**; le fasi mutative (**catalogPush**, **productPricePush**, **pendingEventsFlush**, **finalRefresh**) nel flusso utente pubblico sono **simulate** tramite `SupabaseManualSyncReleaseDryRunPhaseSimulator` (**no** write SwiftData/remota dalla card Release). **`guidedManual`** e **`automatic`** restano esplicitamente non disponibili nel coordinator (**summary bloccato**).

Servizi verticali (**pull apply**, **push catalogo**, **ProductPrice apply/push**, **outbox enqueue/drain**) esistono come moduli separati con test XCTest storici (TASK-039…TASK-061), ma **non** costituiscono ancora una pipeline mutativa **unica mediata dalla UI Release** con conferme e summary atomico sugli effetti applicati/inviati.

## Componenti iOS da leggere / verificare (checklist tecnica)

| Componente | File / area principale | Nota |
| --- | --- | --- |
| Coordinator + modelli run | `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift` | Solo `dryRun` esegue pipeline; `.guidedManual` disabilitato |
| ViewModel + capability Release | `SupabaseManualSyncViewModel.swift` | `supportsRemoteCloudCheck`, `supportsGuidedManualSync: false`, mapping summary |
| Release factory DI | `SupabaseManualSyncReleaseFactory.swift` | Gate auth/baseline, pending locale, adapter preview da `SupabasePullPreviewService` |
| Preview remota adapter | `SupabaseManualSyncRemotePreview.swift` | Mapper privacy-safe preview-only |
| Pull preview paginato | `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift` | Read-only rete |
| Pull apply SwiftData | `SupabasePullApplyService.swift` | Apply locale; **fuori** flusso Release coordinator odierno |
| Push catalogo / preflight | `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, `SupabasePushPreflightViewModel.swift` | Storicamente UI/DEBUG-heavy |
| Baseline lettura/scrittura | `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineWriter.swift`, modelli baseline | Gate Release baseline |
| ProductPrice preview/apply/push | `SupabaseProductPricePreviewService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPriceManualPushService.swift`, dry-run TASK-050 | Percorso prezzi frammentato rispetto a «card Release unica» |
| sync_events preview | `SupabaseSyncEventPreviewService.swift`, reader remoti | Read-only cloud |
| Outbox stato/store/enqueue/drain | `SyncEventOutboxEntry.swift`, `SyncEventOutboxLocalStore.swift`, `SyncEventOutboxEnqueueService.swift`, `SyncEventOutboxDrainService.swift` | Recorder live drain **solo** `#if DEBUG` in app (`iOSMerchandiseControlApp.swift`) |
| Recorder RPC | `SyncEventRecording.swift`, `SupabaseSyncEventLiveRecorder.swift`, transport RPC | Boundary netto TASK-058 |
| Auth | `SupabaseAuthViewModel` / service (via factory gate) | Sessione gate |
| UI Release Options | `OptionsView.swift` — `SupabaseManualSyncReleaseCard` | Nessun SDK diretto nella card |

## Riferimento Supabase locale da verificare **solo in lettura** *(opzionale, fuori repo iOS tipico)*

Nel workspace storico degli altri task e' stato citato un clone progetti separato contenente migrazioni e RPC (percorso indicativo usato in gate documentali passati: **`/Users/minxiang/Desktop/MerchandiseControlSupabase`** — **non** presente obbligatoriamente in questo repo). Il target **`iOSMerchandiseControl`** **non** contiene file `.sql` di produzione nell'albero esaminato.

**TASK-076** autorizza unicamente confronto concettuale / lettura se il clone esiste localmente (**es.** verifica `record_sync_event`, limiti `changed_count`, tabelle mirror Android) — **nessuna** migration o `apply` dal task.

## Riferimento Android — solo **funzionale / documentale**

- Parita' intent e rischi storici sono tracciati in task archivio (**es.** riferimenti incrociati **TASK-033**, note **TASK-068**, roadmap **TASK-084**).
- **Nessun** file Kotlin, **nessun** confronto codebase Android obbligatorio in TASK-076: risultato finale = gap iOS → collegamenti a TASK-084 per parita'.

---

## Tabella audit READY / PARTIAL / MISSING / BLOCKED / OUT OF SCOPE

| Area | Classificazione | Evidenza / motivazione sintetica | Task futuri indicativi |
| --- | --- | --- | --- |
| **Auth/session gate Release** | **READY** | `SupabaseManualSyncReleaseAuthGate` usa sessione signed-in | Hardening in **TASK-085** |
| **Baseline gate Release** | **READY** | `SupabaseCatalogBaselineReader` + esiti `.missing`/`.accountMismatch`/… bloccano coerenti | Refresh post-write sicuro → **TASK-079**, policy conflitto → **TASK-082** |
| **Pending locali aggregati (privacy-safe)** | **READY** | `SupabaseManualSyncLocalPendingSnapshotProvider` + adapter catalogo/outbox | — |
| **Pull preview remota (catalogo)** | **READY** | `SupabasePullPreviewService` + `SupabaseManualSyncPullPreviewAdapter` | Estensioni UX → **TASK-077** |
| **Coordinator `dryRun` + cancellazione/resume summary** | **READY** | Sequenza fasi, finalize remote-preview-only | — |
| **UI Release Options + summary volatile post-run** | **READY** | TASK-072…074; mapping non raw DTO nella card | **TASK-077** conferme esplicite |
| **Percorso `guidedManual` mutativo** | **BLOCKED / MISSING** *(by design ora)* | Coordinator ritorna `summarySliceModeUnavailable()`; capability `supportsGuidedManualSync: false` | **TASK-078** … **TASK-081** dopo decisione governance |
| **Pull apply SwiftData dopo preview Release** | **PARTIAL** | `SupabasePullApplyService` completo per apply locale ma **non** innestato dopo «Controlla cloud» come step confermato | **TASK-078** |
| **Push catalogo reale dopo gate** | **PARTIAL** | `SupabaseManualPushService` ecc. esiste; Release non invoca push reale tramite coordinator | **TASK-079** |
| **ProductPrice end-to-end (preview/apply/push)** | **PARTIAL** | Slice storiche TASK-048…051; nessuna orchestrazione unica Release sicura senza regressione UX | **TASK-080**, smoke **TASK-083** |
| **Outbox enqueue** | **READY** *(locale)* | Producer da outcome terminati (TASK-057) | — |
| **Outbox drain + `record_sync_event` live** | **PARTIAL** | `SyncEventOutboxDrainService` + XCTest; **Release**:** recorder `nil` (`#else`); solo DEBUG wired | **TASK-081** |
| **Error taxonomy UX unificata (mutativo)** | **PARTIAL** | Enum apply/recording ricchi; summary Release non copre ancora tutti gli esiti futuri apply/push/drain combinati | **TASK-074** estensioni mirate vs **TASK-085** osservabilita' |

Classificazioni aggiuntive esplicite:

| Voce | Classificazione | Motivo |
| --- | --- | --- |
| **Sync automatica / background / Realtime** | **OUT OF SCOPE** (roadmap attuale) | Esplicitamente esclusa dalla roadmap TASK-076…085 principale |

---

## Gap principali verso sync mutativa **Release**

1. **`guidedManual` spento**: nessuna esecuzione reale delle fasi **catalogPush** / **productPricePush** / **pendingEventsFlush** / **finalRefresh** dentro il coordinator per l'utente Release — restano solo simulazioni in `dryRun` e stop dopo preview quando il provider remoto e' presente (TASK-071/073 comportamento).

2. **Nessuna conferma UX nativa a due passi «cosa succedera»** prima della mutazione: coperto concettualmente da **TASK-077**.

3. **Pull apply**: servizio robusto (`SupabasePullApplyService`) ma **gap di wiring** sicuro dalla card Release (conferma, staleness, partial) → **TASK-078**.

4. **Push catalogo/ProductPrice/outbox drain**: modularita' presente ma **non** mediata dallo **stesso** flow manuale controllato e dallo stesso modello summary.

5. **Recorder drain Release assente**: costruzione `SupabaseSyncEventLiveRecorder` solo **DEBUG** in `iOSMerchandiseControlApp` → impossibilita' legale tecnica di «drain da Release» senza nuovo wiring esplicito (**TASK-081**).

---

## Gap principali verso **cross-platform iOS ↔ Android**

1. **Schema e semantica** `sync_events` / `record_sync_event` vs client Android storici (**TASK-071 documentato** rischi mismatch) richiedono **TASK-084** dedicato dopo prove iOS (**TASK-083**).

2. **Ordine applicazione** tombstone/metadata/batch size: allineamenti verificati solo con migrazioni + mapper Android offline — fuori questo repo iOS.

3. **Outbox semantics** head-of-line e recovery (**TASK-064**) devono essere validate cross-device dopo drain Release controllato.

---

## Rischi principali (verso «100%» roadmap)

| Rischio | Impatto | Mitigazione proposta *(solo planning)* |
| --- | --- | --- |
| Accensione **`guidedManual`** senza progettazione UX | Doppie scritture / ordine fasi errato | **TASK-077** prima; gate espliciti in planning execution |
| **`partial`** preview + apply combinato | Dati incompleti applicati | Regole staleness/copy gia' in apply service — rivedere in **TASK-078** |
| **ProductPrice** volume/batch (>1000) | Blocco recorder / enqueue | Coperto in roadmap **TASK-080** + hardening backend se necessario |
| **Drain outbox su Release** vs privacy / errore RPC | Esperienza rotta | **TASK-081** con conferma e zero cleanup distruttivo |
| Drift backend Android dopo mesi | Parita' falsata | **TASK-084**, non dichiarare 100% senza prove |

---

## Decisioni provvisorie (TASK-076)

| ID | Decisione | Nota |
| --- | --- | --- |
| D76-01 | L'inventario del repo iOS deve precedere qualunque **EXECUTION** mutativa TASK-077+ | Coerenza CLAUDE/AGENTS |
| D76-02 | **`supportsGuidedManualSync`** resta **false** fino a TASK esplicito (non TASK-076) | Anti-scope utente |
| D76-03 | Audit **NON** equivale a validazione smoke live — **TASK-083** resta autorita' per prove end-to-end |
| D76-04 | UX Release mutativa: **sheet leggera** per riepilogo/conferma; **`confirmationDialog`** solo per azioni ad alto rischio (**D76-UX-01…05**) | Vincolo prodotto per TASK-077 |
| D76-05 | Ordine operativo (#1–#11) qui documentato è **ipotetico**: eventuali riordinamenti tecnici solo con aggiornamento esplicito file task TASK-078…TASK-081 |

---

## Micro-slice future — mapping TASK-077 → TASK-085 *(solo proposta, senza codice)*

| Task | Riallineamento con gap audit |
| --- | --- |
| **TASK-077** | Conferme UX + sheet dopo preview (copre gap «no conferma prima mutazione») |
| **TASK-078** | Collegamento preview → pull apply dopo conferma (gap coordinator vs `SupabasePullApplyService`) |
| **TASK-079** | Push catalogo dopo gate + summary (gap push reale fuori simulator dry-run Release) |
| **TASK-080** | Completezza ProductPrice pull/apply/push e coerenza storico vs Android |
| **TASK-081** | Drain Release + recorder quando autorizzato (gap DEBUG-only oggi) |
| **TASK-082** | Policy conflitti/timestamp (**TASK-068** precursori concettuali) |
| **TASK-083** | Smoke Release controllato integrato multi-fase |
| **TASK-084** | Parita' Android/schema/mapper (**OUT OF REPO iOS** ma dipendenza release) |
| **TASK-085** | Performance, osservabilita', recovery, regressioni finali |

---

## Ordine operativo provvisorio — sync mutativa *(ipotesi di planning, NON implementation)*

Sequenza consigliata da **validare/rafforzare** nei task **TASK-077…TASK-085**; TASK-076 **non** attribuisce priorita' tecnica impegnativa oltre al documento.

| # | Step | Ruolo sintetico | Task indicativi |
| --- | --- | --- | --- |
| 1 | auth/session gate | Blocco se non signed-in | READY oggi; hardening TASK-085 |
| 2 | baseline gate | Allineamento dati cloud sicuro prima di mutation | READY oggi; refresh dopo write **TASK-079** / integrita' **TASK-085** |
| 3 | pull preview read-only | Diff remoto osservabile senza mutazione locale | READY oggi |
| 4 | riepilogo differenze **user-facing** | Sheet/non-tecnico (UX contract sopra) | **TASK-077** |
| 5 | conferma utente | Gates mutativi | **TASK-077** |
| 6 | pull apply locale SwiftData | Write locale post-conferma | **TASK-078** |
| 7 | push catalogo locale → cloud | Upsert sicuro dopo apply coerente | **TASK-079** |
| 8 | ProductPrice pull / apply / push | Ciclo storico/prezzi TASK-049…051 mediato UX | **TASK-080** |
| 9 | drain «operazioni cloud in attesa» *(UI copy, no jargon)* equivalente tecnico sync_events/outbox | Release controllato + recorder | **TASK-081** |
| 10 | refresh baseline/snapshot finale | Coerenza post-write | TASK-079/085 |
| 11 | summary finale | Recap alto livello (TASK-074++) | TASK-074 estensioni / **TASK-085** |

**Nota**: i passaggi 6–9 possono richiedere **micro-riordini** interni dopo review tecnica (**es.** se ProductPrice blocked fino a TASK-080); resta vietato decidere silently in questo documento senza TASK dedicato.

---

## Decisioni sistema vs conferma utente vs differimento

| Decisione tipica | Attore | Commento TASK-076 |
| --- | --- | --- |
| Dimensione batch paginazione / chunk tecnico RPC | **Sistema** | Non esporre numero righe arbitrary all'utente |
| Retry idempotente / backoff conservativo dopo errore retryable | **Sistema** *(con limiti TASK-058/060)* | CTA «Riprova» user-facing dopo fallimento alto livello |
| Apply/push/remoto dopo preview completa sicura | **Utente conferma esplicitamente** (`Applica modifiche` o analogo TASK-077) | No silent mutation |
| Conflitto ambiguo / policy LWW dubbia / tombstone inconsistente osservabile | **BLOCCATO** → **TASK-082** | **Divieto** risoluzione silenziosa TASK-076 |
| Mismatch backend Android vs mapper iOS dopo smoke | **Differimento TASK-084** | Non mascherato come success UX |
| Quando fermarsi su preview `partial` *vs* continuare paginazione | **Sistema** safe default + comunicazione sintetica *«controllo incompleto»* | Dettaglio in TASK-077/078 |

---

## Go / No-Go gates per aprire TASK-077

Decisione di prodotto TASK-076: **Go** verso l'apertura / promozione pianificata di **TASK-077** **solo se** valgono contemporaneamente:

| Condizione **Go** | Nota |
| --- | --- |
| Flusso UX futuro chiaro | **Controlla cloud** → **Rivedi modifiche** → **Conferma** → **Applica / Invia** → **Summary finale** (gia' in § UX contract) |
| Perimetro TASK-077 vincolato | **TASK-077** resta **UX/planning oppure UI-only** su Release: **nessun** apply/push/drain **reale** dentro il perimetro di quel task *(mutazioni = TASK-078+ con override separato)* |
| Jargon vietato in Release | Copy senza termini tecnici in § divieti (outbox, RPC, DTO, …) |
| `supportsGuidedManualSync` | Resta **`false`** finche' un **task mutativo dedicato** (**TASK-078** o successivo esplicito) non lo autorizzi per implementation — **TASK-077 non e' quel task** |
| Ruolo TASK-077 chiaro | TASK-077 **prepara la superficie UX** (sheet, CTA, stati, stub), **non abilita mutazioni** SwiftData/Supabase |

**No-Go / blocco** *(non aprire TASK-077 in EXECUTION Swift o non allargare TASK-077 oltre questo perimetro salvo nuovo planning)*:

| Blocco | Motivo |
| --- | --- |
| Apply + push + drain **nella stessa** EXECUTION di TASK-077 | Troppo mutativo; rompe serialita' **TASK-078…081** |
| Nuova **schermata / nav stack pesante** senza motivazione documentata | Contraddice **D76-UX-03** |
| Promessa **«tutto sincronizzato»** o equivalente fuorviante | Contraddice TASK-074/075 e DoD anti-promessa |
| Nessuna distinzione UX tra **dati locali modificati**, **dati cloud da applicare**, **operazioni in attesa** *(linguaggio naturale)* | Rischio errore utente e conflitti TASK-082 |

---

## Struttura UX consigliata della sheet futura *(TASK-077, solo planning)*

**Decisione UX TASK-076:** card compatta in **`OptionsView`** + **sheet SwiftUI leggera**; **nessuna** nuova schermata pesante finche' la sheet basta. Stile generale: **Apple-like**, sezioni semplici, gerarchia chiara, copy breve *(dettaglio in l10n TASK-077)*.

Struttura **proposta** (non implementazione, non testo finale stringa):

| # | Blocco | Contenuto indicativo |
| --- | --- | --- |
| 1 | **Header** | Titolo user-facing *(es. «Rivedi modifiche cloud»)*; sottotitolo breve *(es. «Controlliamo cosa puo' essere aggiornato prima di applicare modifiche.»)* |
| 2 | **Dal cloud al dispositivo** | Sintesi delle differenze **applicabili in locale**; **zero** dettaglio tecnico |
| 3 | **Dal dispositivo al cloud** | Modifiche **locali pronte per l'invio**; chiaro che l'invio **solo dopo** conferma *(anche se il bottone vera' in TASK-078+)* |
| 4 | **Prezzi** | **ProductPrice** tracciato separatamente *(pericolosita' TASK-080)*; se non supportato nella fase: messaggio tipo *«Prezzi da controllare in un passaggio dedicato.»* |
| 5 | **Attenzione** | Solo se **partial**, rischio sessione/conflitto: riassunto sintetico, **senza** stack/trace |
| 6 | **Footer CTA** | **Primaria:** *Applica modifiche*; **Secondaria:** *Annulla*; **Alternativa:** *Riprova* se preview incompleta o fallita *(stati nominati nella tabella § Stati user-facing futuri)* |

*Nota planning:* se TASK-077 e' solo shell UI, alcune sezioni possono contenere placeholder copy finche' **TASK-078…080** definiscono i dati reali — ma la **gerarchia** sopra resta il target.

---

## Regole visive UI Release *(linee guida planning)*

- **Ingresso:** la **card** in `OptionsView` resta l'unico punto di ingresso principale alla sync Release.
- **Card compatta:** titolo, sottotitolo, badge stato, **una** CTA primaria per stato dove possibile; **nessun dump** di dettaglio sulla card.
- **Dettaglio nella sheet**, non sulla card *(coerenza con sopra)*.
- **SF Symbol suggeriti** *(coerenti, non obbligatori nell'implementazione futura)*: `cloud`/check per controllo ok; `arrow.triangle.2.circlepath` per ripetizione/sync; `exclamationmark.triangle` per attenzione; `checkmark.circle` per completamento positivo; `xmark.circle` per fallito/cancellato.
- **Colore:** preferire **colori semantici** SwiftUI *(`.secondary`, semantic success/warning quando applicabile)*; evitare palette custom invasive.
- **VoiceOver:** `accessibilityLabel` che combini **titolo + stato alto livello + azione della CTA** senza jargon.
- **Copy:** massimo **1–2 frasi** per blocco nella sheet/card principale.
- **Vietato in Release:** ID grezzi raw, liste lunghe barcode, linguaggio tipo payload/DTO/stack error *(allineamento § UX contract)*.

---

## Matrice cross-platform minima *(preparazione TASK-084)*

Solo **planning**: **nessun** test Android, **nessuna** execution. Le celle sono **intent** di verifica futura smoke **TASK-083** / parita' **TASK-084**.

Legenda sintetica stato atteso *(non esaustiva)*: **PARTIAL** = copertura nota incompleta; **TBD** = da confermare dopo smoke; **HIGH** rischio se drift mapper/schema.

| Entita' / aspetto | Android → Supabase → iOS | iOS → Supabase → Android | Stato atteso *(oggi/indicativo)* | Rischio | Task responsabile |
| --- | --- | --- | --- | --- | --- |
| **Product** | Round-trip SKU/barcode/`remoteID` coerenti | Idem verso Android | PARTIAL *(apply/push mediati)* | Divergenza FK/tombstone | **TASK-078 / 079**, **TASK-084** |
| **Supplier** | Upsert/read-back allineati | Idem | PARTIAL | Nomi omografi | **TASK-079**, **TASK-084** |
| **Category** | Idem Supplier | Idem | PARTIAL | Idem | **TASK-079**, **TASK-084** |
| **ProductPrice current** *(prezzo corrente effettivo)* | Visibilita' comportamento dopo push/pull | Bidirezionale sicuro solo post-TASK-080 | PARTIAL — **HIGH** | Storico vs current | **TASK-080**, **TASK-084** |
| **ProductPrice history** *(storico righe)* | Ordine deterministico/`effective_at` | Idem | PARTIAL — **HIGH** | Cap batch / dedupe | **TASK-080**, **TASK-084** |
| **sync_events** / «operazioni in attesa» | Eventi registrati leggibili lato Android | Drain iOS dopo Release (**TASK-081**) compatibile semantics | PARTIAL — **HIGH** | `record_sync_event` contract | **TASK-081**, **TASK-084** |
| **Delete / tombstone** *(se supportato)* | Comportamento allineato RLS/policy | Evitare wipe silenzioso | **TBD** | Dati persi UX | **TASK-082**, **TASK-084** |
| **Conflitto / timestamp** (`updated_at`, LWW…) | Merge policy documentata | Idem | **TBD — BLOCK prima di merge cieco** | **HIGH** | **TASK-082**, **TASK-084** |
| **Import / export Excel** *vs dati sincronizzati* | Non invalida tacitamente cloud senza UX | Chiarezza baseline post-import | **OUT OF PLANNING ora** *(non questo file)* drift possibile | **MED/HIGH** se ignorato | **Follow-up backlog** fuori TASK-084 stretto |

---

## Crash / partial / recovery policy *(futuro, solo planning)*

Linee guida per **TASK-085** hardening + stati TASK-078…:

| Principio | Contenuto |
| --- | --- |
| Restart dopo crash | Dopo crash durante una sync **futura**, al riavvio **vietato** mostrare **«completato»** senza **riconciliazione/consultazione stato** persistente sicuro *(needsReview)* |
| Stati terminati mutativi *(target)* | Ogni step mutativo **futuro** deve mapparsi a **`completed`** / **`partial`** / **`failed`** / **`cancelled`** / **`needsReview`** *(estensione stati nominale § precedente)* |
| **partial** UX | Summary: cosa resta **sicuro** *(verificabile)* vs cosa va **Riprovato** / **rivedere**; mai mascherare partial come OK |
| Rollback | **No** rollback **distruttivo** automatico verso stato ignoto *(preferenza TASK-063 family)* |
| Retry | Preferire **idempotenza servizio + retry manuale** utente dopo messaggio sintetico |
| Conflitti | Ambiguo → **STOP** UX + **TASK-082** *(no merge silenzioso)* |

La UI deve **sempre** distinguere (**linguaggio naturale**, anche se stato interno e' uno solo):

| Concetto utente | Esempi copy *(indicativi TASK-077 l10n)* |
| --- | --- |
| Modificate **in locale** | «Modifiche salvate sul dispositivo» |
| Inviate / applicate **dal cloud in locale** | «Aggiornamenti dal cloud applicati sul dispositivo» |
| **Non completate** | «Passaggio non completato — puoi riprovare» |
| **Saltate** *(richiedono review TASK-082)* | «Alcuni elementi richiedono un controllo manuale» |

---

## Regola anti-confusione utente *(CTA future)*

Ogni **CTA mutativa** futura deve **nominare l'effetto** senza gergo:

| CTA / etichetta *(target)* | Effetto dichiarato |
| --- | --- |
| **Applica modifiche** | Scrive / aggiorna **dati locali SwiftData** in base a quanto dichiarato in revisione (**pull apply**) |
| **Invia al cloud** / equivalente naturale | Esegue **scrittura su Supabase** (push catalog / prezzi / operazioni…) **dopo** conferma adeguata |
| **«Sincronizza ora»** *(o sinonimo forte)* | Usabile **solo** quando il flusso **reale e verificato** include **sia** apply locale **sia** push nel perimetro dichiarato del task/smoke (**TASK-083**); altrimenti **No-Go** copy |

**Finché** il flusso resta **read-only**, usare **`Controlla cloud`** *(o analogo TASK-072)* — **non** **«Sincronizza»** come se fosse bidirezionale completo.

---

## Definition of Done — **planning** per TASK-076

TASK-076 si considera **pronto per la review planning documentale** (non DONE del task progetto finche' Claude/owner non chiude formalmente il planning) quando valgono cumulativamente:

| # | Criterio |
| --- | --- |
| DoD-P1 | Audit repo-grounded **leggibile** (tabelle READY/PARTIAL…) completo nell'articolo tecnico sopra |
| DoD-P2 | Ogni macro-gap collegabile a **TASK-077…TASK-085** nella tabella mapping + ordine operativo |
| DoD-P3 | **UX contract** Release mutativo futuro definito (flusso, divieto jargon Release, sheet vs dialog) |
| DoD-P4 | **Ordine operativo ipotizzato** (#1–#11) documentato come non-implementativo |
| DoD-P5 | Tabella **sistema vs utente vs bloccati** presente |
| DoD-P6 | **Anti-scope** TASK-076 rispettato (zero Swift/backend live in questo stream) |
| DoD-P7 | Handoff: **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION** |
| DoD-P8 | **TASK-076 restava ACTIVE / PLANNING fino alla chiusura documentale**: il passaggio a TASK-077 execution avviene in task separato e con override utente; TASK-076 ora e' **DONE / Chiusura** come planning-only |
| DoD-P9 | **Go / No-Go TASK-077** definisce gate di apertura e blocchi UX/mutativo |
| DoD-P10 | Struttura **sheet**, **regole visive Release**, **matrice cross-platform minima TASK-084**, **policy crash/partial/recovery**, **regola anti-confusione CTA** integrate come prerequisiti concettuali per TASK-077…TASK-085 |

Con la chiusura formale della fase PLANNING TASK-076, lo **stato ufficiale** e':

- **TASK-076 DONE / Chiusura**
- **Planning audit chiuso**
- **NON READY FOR EXECUTION per TASK-076** *(execution spostata in task successivi, a partire da TASK-077)*

## Checklist review planning *(Claude / utente)*

- [ ] Le classificazioni **READY/PARTIAL** sono coerenti con `SupabaseManualSyncCoordinator.swift` (modalita' `.guidedManual` disabilitata) e Release factory?
- [ ] I gap Release mutativa vs **servizi esistenti** sono chiari (**apply/push/drain** modulari)?
- [ ] Nessuna promessa **implicita** di sync completa o parita' Android nel testo sopra senza rimando a TASK-084/083?
- [ ] UX contract (sheet, jargon vietato Release, ordine operativo #1–#11) adeguato prima di EXECUTION TASK-077?
- [ ] **Go TASK-077** verificabile: TASK-077 = superficie UX / UI-only, **senza** apply/push/drain reale nel perimetro TASK-077?
- [ ] **No-Go** assente: niente «tutto sincronizzato», niente schermata pesante senza motivazione, distinzione locale/cloud/operazioni pendenti chiara?
- [ ] Anti-scope tecnico TASK-076 rispettato (no Swift edits in questo task)?

---

## Anti-scope task documentale *(ripetizione esplicita)*

Come da richiesta progetto **TASK-076**:

- Nessun Swift, nessun `pbxproj`, nessun `Localizable`.
- Nessun SQL/migration/backend live.

---

## Handoff finale

| Voce | Valore |
| --- | --- |
| **Task / stato** | **TASK-076 DONE / Chiusura** |
| **Planning review testuale** | Chiuso come audit/planning documentale su richiesta utente |
| **Execution Swift / Codex** | **NON READY FOR EXECUTION per TASK-076** — TASK-076 non contiene e non autorizza Swift execution |
| **Chiusura fase PLANNING** | Completata come chiusura documentale; la execution successiva vive in **TASK-077** |

---

## Planning (Cursor / Agent — bozza compilata per questo task PLANNING ONLY)

Questa sezione sostituisce il ciclo Claude/Codex classico finche' il reviewer non firma il planning documentale.

### Analisi
Il repository iOS contiene uno **stack modulare solido**: pulling, applying, pushing e sync_events sono stati consegnati in **task verticali** (TASK-039…TASK-061) con eccellente copertura test **per modulo**. Il **glue** tipo «unica esperienza Release mutativa sicura» passando dal **`SupabaseManualSyncCoordinator`** in modalita' diversa dal `dryRun` read-mostly **non e' ancora parte del codebase**: e' il divario centrale TASK-076→077+.

### Approccio proposto
Mantenere i task successivi **seriali minimali**: prima conferme (**TASK-077**), poi apply (**TASK-078**), poi push (**TASK-079**), poi prezzi (**TASK-080**), poi outbox (**TASK-081**) — come backlog gia' definito nel MASTER-PLAN, eventualmente ripacchettabile solo dopo secondo audit post-TASK-077.

### Rischi documentali
Messaggi fuorvianti «quasi finito»: mitigazione = **solo** READY dove esiste comportamento osservabile in Release oggi; il resto **PARTIAL** o **MISSING/BLOCKED by design**.

### Handoff verso reviewer
- **Prossima fase**: PLANNING REVIEW *(documentale)*
- **Prossimo agente**: CLAUDE / Planner o proprietario workspace
- **Azione**: approvare/perfezionare TASK-076; poi IDLE o promuovere TASK-077 PLANNING quando desiderato

---

## Review / Chiusura documentale (Codex — 2026-05-08 12:44 -0400)

### Verifica coerenza planning-only
- TASK-076 e' coerente con il suo contratto **planning-only**: audit repo-grounded, Go/No-Go TASK-077, struttura sheet, regole visive, policy recovery e mapping TASK-077…TASK-085.
- Lo stato precedente riportava **READY FOR PLANNING REVIEW** e **NON READY FOR EXECUTION**: la chiusura non trasforma TASK-076 in execution.
- Verifica stato git pre-chiusura: risultavano modificati solo `docs/MASTER-PLAN.md` e il nuovo file task TASK-076; nessun file Swift, backend, SQL, Android, `project.pbxproj` o `Localizable` risultava modificato da TASK-076.

### Chiusura
- **TASK-076 e' chiuso come audit/planning, non come implementazione.**
- **Nessuna sync mutativa e' stata abilitata.**
- **Nessun apply, push o drain e' stato eseguito.**
- **Nessun `guidedManual` e nessun `supportsGuidedManualSync = true` e' stato introdotto da TASK-076.**
- Il lavoro operativo successivo e' tracciato separatamente in **TASK-077**.

---
