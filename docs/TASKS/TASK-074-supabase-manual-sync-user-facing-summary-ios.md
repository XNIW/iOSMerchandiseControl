# TASK-074 — Summary finale user-facing per Supabase manual sync iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-074 |
| **Titolo** | Summary finale user-facing per Supabase manual sync iOS |
| **File task** | `docs/TASKS/TASK-074-supabase-manual-sync-user-facing-summary-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 10:37 -0400 — REVIEW tecnica **S74-a** completata con fix documentale/tracking: codice approvato nel perimetro read-only, check finali PASS, **TASK-074 DONE / Chiusura** su override utente. |
| **Ultimo agente** | Codex / Reviewer+Fixer+Closer |

### Nota autorizzazioni (TASK-074)

Questo task nasce come **planning-only** (markdown), poi e' stato promosso con override utente esplicito alla sola EXECUTION **S74-a**: summary read-only compatto e volatile post **«Controlla cloud»**. Lo storico planning-only sotto resta valido come contesto e guardrail; la chiusura **DONE / Chiusura** riguarda esclusivamente la slice **S74-a** implementata, revisionata e verificata.

Durante execution/review sono rimasti non autorizzati e non implementati:

- `guidedManual` eseguibile e `supportsGuidedManualSync = true`;
- `SupabasePullApplyService`, push catalogo, ProductPrice push, outbox drain/cleanup/reset/truncate nel path Release summary;
- Timer, BGTask, Realtime, polling, retry automatici/background;
- backend Supabase, SQL/migration, Android, nuovo schema SwiftData, `project.pbxproj`;
- persistenza del summary in SwiftData/UserDefaults/AppStorage/FileManager/file;
- nuovo flusso di conferma mutativa, cronologia controlli o audit log.

**TASK-075** non viene avviato e resta **TODO**.

---

## Dipendenze

- **Dipende da**
  - **TASK-073** (**DONE / Chiusura**) — S73-a: preview remota read-only cablata in Release (`SupabaseManualSyncPullPreviewAdapter` + `SupabasePullPreviewService`), `supportsGuidedManualSync` sempre false, zero mutazioni.
  - **TASK-072** (**DONE / Chiusura**) — card Release, `SupabaseManualSyncPresentationState`, capability-driven, `options.supabase.manualSync.*` IT/EN/ES/zh-Hans.
  - **TASK-071** (**DONE / Chiusura**) — `SupabaseManualSyncRemotePreviewSummary`, mapper privacy-safe, niente `SyncPreview` in UI Release.
  - **TASK-070** (**DONE / Chiusura**) — semantica preview read-only, partial vs pending locale, policy copy.
  - **TASK-063** (**DONE / Chiusura**) — orchestratore production-safe, `RunSummary` / fasi / boundary (riferimento concettuale).
- **Sblocca** — UX finale comprensibile post-run per smoke operativo **TASK-075** (evidenze manuali piu' leggibili); **TASK-075** resta separato e non viene avviato da TASK-074.

---

## Obiettivo

Pianificare come trasformare gli **esiti tecnici** di una run manuale Supabase (`RunSummary`, `PhaseOutcome`, `SupabaseManualSyncRemotePreviewSummary`, aggregati interni) in un **summary finale chiaro, utile e user-facing** nella UI Release (card «Sincronizzazione cloud»), **senza** esporre DTO, payload raw, `SyncPreview`, outbox, drain, RPC, dettagli di fase tecnica.

Compatibilita' obbligatoria con **S73-a read-only** oggi: informativo, **non** promette «cloud aggiornato»; distingue controllo completato / incompleto / differenze da esaminare / errori categoria privacy-safe.

---

## Stato attuale iOS (repo-grounded)

| Area | Situazione |
|------|------------|
| **`SupabaseManualSyncRunSummary`** + **`SupabaseManualSyncFinalUserState`** | Gia' in `SupabaseManualSyncCoordinatorModels.swift`: headline UX, fasi eseguite/saltate, `countsSnapshot` privacy, `remotePreviewSummary` opzionale. |
| **`SupabaseManualSyncRemotePreviewSummary`** + **`SupabaseManualSyncRemotePreviewMessageKey`** | In `SupabaseManualSyncRemotePreview.swift`: aggregati sicuri, `recommendedUserMessageKey`, `failureCategory` interna. Mapper collega `SyncPreview` **solo** lato servizio — la UI Release non deve ricevere `SyncPreview`. |
| **`SupabaseManualSyncViewModel`** | Mappa `apply(summary:)` su `presentationKind` + titoli/sottotitoli interni (italiano hardcoded in parte) e **`makePresentationState()`** usa chiavi **`options.supabase.manualSync.state.*`** per la card. Caso speciale: `technicalReviewNeeded` + segnali preview remoti → UI stile «modifiche da controllare» (`hasCompletedRemotePreviewSignals`). |
| **`SupabaseManualSyncPresentationState`** | Snapshot unico per SwiftUI: titolo/sottotitolo localizzati, badge, CTA, running. |
| **`OptionsView` + card Release** | Consumano solo `presentationState`; **nessuna** logica business pesante desiderata in vista (**D72-17**). |
| **Localizable** | Set gia' ampio sotto `options.supabase.manualSync.*` (IT/EN/ES/zh-Hans) per stati card; il «summary finale» ricco come **blocco aggiuntivo** non e' ancora modellato esplicitamente. |

**Gap UX attuale:** l'utente ottiene titolo/sottotitolo/badge dalla card, ma manca un **contratto esplicito** «cosa e' successo nell'ultimo controllo» (summary narrativo compatto) separato dai messaggi generici di idle/success/partial; inoltre **termini interni** (`technicalReviewNeeded` per segnali cloud) sono mappati su copy «modifiche da controllare» — va reso **stabile e documentato** come intenzione UX, non come effetto collaterale.

---

## Riferimenti TASK usati

| Task | Uso per TASK-074 |
|------|------------------|
| **TASK-063** | Taxonomy `FinalUserState`, headline non jargon, partial sempre visibile (**D63-08**). |
| **TASK-070** | Preview read-only, partial cloud, copy «incompleto», no «tutto aggiornato» senza prova. |
| **TASK-071** | Summary aggregato remoto, confine `SyncPreview`. |
| **TASK-072** | Presentation state unico, capability nascondi vs disabilita (**D72-21**), no redesign pesante. |
| **TASK-073** | Stati S73-a, suggested copy indicativo, `Remote cloud check UX states`, zero mutazioni. |

---

## Decisioni TASK-074 (D74)

| ID | Decisione |
|----|-----------|
| **D74-01** | Separare **`SupabaseManualSyncRunSummary`** (tecnico/aggregato gia' esistente) da un **`SupabaseManualSyncUserFacingSummary`** (nome indicativo) — **solo contratti in planning**: struttura presentazionale con enum/stati **utente**, stringhe risolte tramite **`Localizable`**, nessun tipo rete/DTO nella struttura esposta alla UI Release. |
| **D74-02** | Il mapping **`RunSummary` + `RemotePreviewSummary` (se presente) + `PrivacyCounts`** → `UserFacingSummary` resta nel **ViewModel** (o helper dedicato nello stesso modulo), **non** in `OptionsView`. |
| **D74-03** | **S73-a read-only:** il summary finale non puo' affermare «cloud aggiornato» / «sincronizzazione completata con il cloud» come esito del solo controllo; formulazioni consentite: **controllo completato**, **nessuna azione richiesta**, **differenze da esaminare** (senza elenchi), **controllo incompleto**, **connessione / sessione / problema generico**. |
| **D74-04** | **Pending locali zero:** usare **«Non risultano modifiche locali da inviare»** (o parity 4 lingue) dove applicabile; **vietato** «Tutto sincronizzato» come frase unica se puo' implicare parita' cloud senza verifica (allineamento **D72-25**). |
| **D74-05** | **Segnali/differenze cloud:** mostrare messaggio tipo **«Ci sono modifiche da controllare»** / **«Ci sono elementi sul cloud da rivedere»** (draft) — **nessun** dettaglio riga, barcode, nome prodotto, supplier/category **non aggregati**. |
| **D74-06** | **Partial preview:** titolo dominante **«Controllo cloud incompleto»** (o chiave dedicata); sottotitolo invita a riprovare; **non** usare «sync parziale» in Release per la sola preview (**UX contract TASK-073**). |
| **D74-07** | **Errore:** categorie user-facing = rete / sessione-permessi / generico; **mai** stack, codice RPC, UUID, snippet JSON. |
| **D74-08** | **UI:** summary **compatto** nella card (1–2 righe + badge coerente); eventuale **`DisclosureGroup`** o **`.sheet` leggero** solo se serve chiarire **messaggi aggregati** (es. conteggi alto livello **opzionali** in futuro) — niente lista tecnica. |
| **D74-09** | **Funzioni non disponibili:** **nascoste**; **disponibili ma during run:** **disabilitate** con hint accessibile (**D73-14** / **D72-21**). |
| **D74-10** | **Futuro mutativo (`guidedManual`):** definire **solo contratto** testuale in questo task — stati come controllato / applicato localmente / inviato / in coda / saltato / fallito / parziale / bloccato — **nessuna** implementazione finche' non esiste slice dedicata post-**supportsGuidedManualSync**. |
| **D74-11** | **Localizzazione:** nuove chiavi sotto prefisso **`options.supabase.manualSync.summary.*`** (indicativo) per blocchi summary; **vietate** in stringhe Release: outbox, drain, RPC, DTO, SyncPreview, payload, sync_events. |
| **D74-12** | **Test futuri:** mapping ViewModel, UI test no-jargon, parity 4 lingue, grep anti-scope; read-only non mutativo in S74-a. |
| **D74-13** | **No duplicate copy:** non ripetere la **stessa frase** in title, subtitle e summary della card; se il **titolo** gia' comunica *«Ci sono modifiche da controllare»*, il **summary compatto** deve aggiungere contesto distinto (es. *«Nessun invio automatico»*, *«Controllo cloud completato»*, esito temporale) — **non** un clone del titolo; se il summary **non aggiunge informazione** rispetto a title/subtitle, **ometterlo**; preferire **meno testo** a testo ridondante (**vedi** § Presentation hierarchy, § Summary priority rules). |
| **D74-14** | **OptionsView is rendering-only:** `OptionsView` **non** decide stato, priorita' tra messaggi, mapping tecnico→UX, error taxonomy, verifica **no-duplicate-copy**; riceve gia' un **presentation state** (e, in S74-a, eventuale summary) **pronto** dal **ViewModel**; il calcolo del summary resta nel **ViewModel** / helper nello stesso modulo. Test futuri (**T74-12** e affini) devono **fallire** se `OptionsView` (o subview card) contiene **branching business pesante** legato al summary (if su outcome tecnici, mapping errori, dedup copy inline). |
| **D74-15** | **Existing copy migration must be conservative:** non **sostituire** in blocco le chiavi **`state.*`** gia' usate se il comportamento attuale e' accettabile; **S74-a** aggiunge il **summary** senza **rompere** titolo/sottotitolo esistenti salvo review mirata; eventuale **deduplicazione** tra `state.*` e `summary.*` solo con **snapshot di presentation** / test di regressione, **non** a intuito; se il **subtitle** corrente e' gia' sufficiente, il campo summary puo' restare **`nil`/ assente** (**D74-13**). |
| **D74-16** | **Summary is ephemeral, not history:** **S74-a** mostra solo l'**ultimo esito utile** nella card Release (eco dell'ultimo «Controlla cloud»), **non** una lista di run, **non** storico tecnico, **non** log. Allineato a **§ Summary storage policy**. |
| **D74-17** | **Summary localization is additive:** **S74-a** puo' aggiungere chiavi **`options.supabase.manualSync.summary.*`**; **non** rimuove e **non** riscrive in massa le chiavi **`state.*`**; se serve cambiare copy esistente, solo **micro-diff** motivato (**no-duplicate-copy**, bug UX, parity); **IT / EN / ES / zh-Hans** restano **semanticamente allineate** (**D74-15**). |

---

## UX contract (Release)

1. **Informativo, non celebrativo:** dopo «Controlla cloud» read-only, il copy rassicura su **cosa e' stato fatto** (lettura) e **cosa no** (nessun invio applicato automaticamente).
2. **Onesta semantica:** «Completato» = fase preview letta con esito mappato; non implica allineamento dati applicato.
3. **Segnali remoti:** comunicare **presenza di elementi da rivedere**, non cataloghi tecnici.
4. **Accessibilita':** summary comprensibile con VoiceOver (titolo + sottotitolo + badge gia' previsti; eventuale riga summary annunciata come parte di `accessibilityLabel` o stringa unica coerente — da definire in execution).
5. **Coerenza con `SupabaseManualSyncPresentationState`:** il summary user-facing e' un **estensione** del messaggio card, non un secondo flusso concorrente con copy contraddittorio.

---

## Presentation hierarchy

Gerarchia tra gli elementi della card Release **esistente** e il **summary compatto** pianificato — cosi' convivono senza duplicare messaggi ne' richiedere redesign (**D74-08**, **D72-20**).

| Livello | Ruolo | Regola |
|---------|-------|--------|
| **Titolo card** | Messaggio primario **immediato** (stato dominante percepito in un colpo d'occhio). | Una sola idea per stato; resta la «testata» della card. |
| **Sottotitolo card** | Messaggio secondario **contestuale** (perche', cosa fare dopo, rassicurazione). | Completa il titolo senza ripeterlo letteralmente. |
| **Badge** | Stato **visivo** (icona + etichetta breve gia' in `SupabaseManualSyncPresentationState`). | Comunica categoria (manuale, in corso, errore, …); **non** sostituisce titolo/sottotitolo né contiene paragrafi. |
| **Summary compatto** (pianificato S74-a) | **Contesto sull'ultimo controllo** («ultima run» / esito dell'ultimo «Controlla cloud») quando aggiunge chiarezza **oltre** title/subtitle **senza** ripeterli. | Massimo **1–2 righe**; se ridondante con title **o** subtitle → **omit** (**D74-13**). |
| **DisclosureGroup / `.sheet`** (opzionale) | **Solo** se servono **piu' gruppi** di messaggio user-facing o **2–4 righe** aggregate **utili** (vedi § Compact row vs disclosure vs sheet policy). | In **S74-a** la card resta **leggera**; niente redesign pesante. |

**Decisione UX sintetica:** title/subtitle restano il messaggio primario; il summary compatto **non** e' un secondo titolo — integra o chiarisce l'**ultimo esito** del controllo cloud; badge rinforza la categoria senza sostituire testo; disclosure/sheet solo quando il valore aggiunto supera il compact row.

---

## Proposed presentation model — planning only

Struttura **indicativa** per una futura implementazione **S74-a** — **nessun codice Swift** in questo task. Nomi di campo sono **concettuali**; in EXECUTION potranno essere tipi Swift **Sendable**, costruiti nel **ViewModel** o helper nello stesso modulo, **mai** in `OptionsView`.

| Campo (indicativo) | Scopo |
|--------------------|--------|
| **`kind`** | Enum user-facing dello **stato presentazionale** del summary (es. noAction, remoteSignals, partial, network, …) — **non** phase enum del coordinator ne' esiti raw. |
| **`titleKey`** | Chiave `Localizable` per **titolo card** (puo' riusare o affiancare lo stream gia' in `state.*` — da consolidare in execution per evitare drift). |
| **`messageKey`** | Chiave primaria per **prima riga** di messaggio utente coerente con il summary (controllo completato, differenze, errore, …). |
| **`secondaryMessageKey`** | Chiave opzionale per **seconda riga** (es. «Nessun invio automatico.») — **vuota** se ridondante (**D74-13**). |
| **`badgeKind`** | Descrittore **non tecnico** per abbinare badge (mapping verso testo + SF Symbol gia' usati nella card). |
| **`detailRows`** | Elenco **opzionale** di righe **corte**, gia' risolte in stringhe localizzate — **no** identificatori, **no** liste prodotto; solo aggregati o messaggi ammessi dalla privacy policy. |
| **`allowsDisclosure`** | Flag logico: **true** solo se § policy consente disclosure (2–4 righe utili). |
| **`accessibilitySummaryKey`** | Chiave **unica** o composizione per VoiceOver (titolo + messaggio + esito ultimo controllo senza esporre jargon). |

**Vincoli:**

- **Non** includere: DTO, `SyncPreview`, payload raw, `Phase` / `PhaseOutcome` enum grezzi, ID, stack.
- Proposta **solo planning**; revisionabile in review execution.
- Se implementata: tipi **Sendable**, mapping **testabile** (pure function / snapshot ViewModel).

---

## S74-a read-only summary state machine

Stati **minimi** logici per il summary / presentazione **dopo** o **durante** il percorso read-only **S74-a**. **Mutazioni consentite: sempre NO** (nessun apply/push/drain/enqueue dalla card in questa slice).

| Stato | Cosa vede l'utente (concept) | Summary compatto | Disclosure / sheet | Mutazioni |
|-------|------------------------------|-------------------|--------------------|-----------|
| **idleNoRun** | Card in riposo; copy idle/footer capability; eventuale hint «ultimo controllo» solo se non stale (vedi priority rules). | Opzionale, solo se aggiunge fatto utile (es. ultimo esito breve) | No / No | **No** |
| **checking** | Running: progress + «Controlla cloud» / operazione in corso; **Annulla** se previsto. | Di solito **no** (title/subtitle running bastano) | No / No | **No** |
| **completedNoAction** | Controllo terminato; nessun segnale rilevante dal cloud. | **Si** (es. «Controllo completato» / «Nessuna azione richiesta») se non ridondante con subtitle | No / No | **No** |
| **completedWithRemoteSignals** | Controllo terminato; ci sono elementi da rivedere sul cloud (senza elenchi). | **Si** — deve **complementare** il titolo (es. titolo = attenzione, summary = nessun invio auto) (**D74-13**) | Solo se policy | **No** |
| **completedNoLocalPending** | Aggregato locale: nessuna modifica in sospeso **locale** (non equivale a cloud allineato). | **Si** (chiave dedicata pending) **oppure** solo subtitle se gia' coperto | No / No | **No** |
| **partial** | Preview incompleta / budget / esito parziale. | **Si** (controllo incompleto + riprova) | Sheet **solo** se copy aggregato multi-riga **davvero** necessario | **No** |
| **failedNetwork** | Errore connettivita'. | **Si** (breve) | No / No | **No** |
| **failedSession** | Sessione / permessi / accesso cloud. | **Si** (accedi / accesso necessario) | No / No | **No** |
| **failedGeneric** | Errore generico privacy-safe. | **Si** | No / No | **No** |
| **cancelled** | Utente ha annullato; non come errore fatale. | **Si** (operazione annullata) | No / No | **No** |
| **alreadyRunning** | Un'altra operazione gia' in corso / busy. | Di solito **no** (stato busy gia' in title) | No / No | **No** |

---

## Compact row vs disclosure vs sheet policy

| Livello | Policy S74-a |
|---------|----------------|
| **Default** | Summary **compatto** nella card (1–2 righe), **sotto** sottotitolo o in riga dedicata **secondaria** — senza aumentare il «peso» della card. |
| **DisclosureGroup** | Solo se esistono **2–4** righe aggregate **realmente utili** e **non ridondanti** (mai lista fasi tecniche). |
| **Sheet** | Solo se l'esito **parziale** o un **blocco** richiede **piu** contesto user-facing **in un unico luogo**; **vietato** sheet per ogni successo banalmente confermato dal titolo. |
| **Divieti** | Nessuna lista di **fasi** coordinator; nessun **raw count** troppo dettagliato (nessun conteggio per tipo che implichi inventario identificabile); niente sheet «informativo» vuoto. |

---

## Summary priority rules

Regole di **precedenza** quando stati si sovrappongono o la sessione cambia — da applicare in **execution** (ViewModel / helper), **non** in `OptionsView`.

1. **Auth / baseline block** vincono sempre su qualsiasi **summary di run precedente** (la card deve chiedere prima *Accedi* / *Riallinea* — non mostrare un «ultimo controllo ok» obsoleto).
2. **Running** vince sull'**ultimo summary** statico: durante `checking` / busy il messaggio dominante e' progresso, non il riepilogo della run precedente (salvo micro-footnote non distrattiva — **opzionale** e solo se non ambigua).
3. **Cancelled:** mostra esito **annullamento** neutro, **non** come fallimento grave; non contraddire la voce **Annulla** con stato errore rosso ingiustificato.
4. **Partial** vince su **success** se entrambi applicabili nello stesso framing (l'utente deve vedere **incompleto** prima di «tutto ok»).
5. **Remote signals** (differenze da esaminare) vincono su **«nessuna azione»** / no signal per lo **stesso** controllo cloud.
6. **No local pending** **non** equivale a **«cloud allineato»** / «tutto sincronizzato» — restano messaggi distinti (**D74-04**).
7. **Summary stale** dopo **logout**, **cambio account** o **invalidazione sessione**: in execution futura il summary dell'ultimo controllo va **nascosto** o **invalidato** finche' l'auth non e' di nuovo coerente (evita messaggi fuorvianti).

---

## S74-a execution brief — planning only

Brief operativo per la **futura** EXECUTION **S74-a** (solo testo; **nessun** codice in questo task):

| Aspetto | Linea guida |
|---------|-------------|
| **Obiettivo slice** | Introdurre un **summary presentazionale read-only** che descriva l'esito dell'**ultimo** «**Controlla cloud**» (ultima run preview-only completata), senza cambiare il **significato** della CTA: resta **lettura / consapevolezza**, non applicazione dati. |
| **Fonti dati** | Solo quanto gia' fluisce in **ViewModel** da **`SupabaseManualSyncRunSummary`**, **`SupabaseManualSyncRemotePreviewSummary`** (se presente), **`SupabaseManualSyncPrivacyCounts`** — **nessun** nuovo fetch inventato in `OptionsView`. |
| **CTA e capability** | **Non** abilitare «**Sincronizza ora**»; **`supportsGuidedManualSync`** resta **false**. **Non** cambiare la semantica di «Controlla cloud». |
| **Mutazioni** | **Nessun** apply, push catalogo, ProductPrice push, drain, enqueue forzato, cleanup outbox. |
| **Coordinator** | **Non** modificare il **coordinator** se il mapping summary→UI puo' vivere nel **ViewModel** o in un **helper** nello stesso modulo (**D74-02**, **D74-14**). |
| **`OptionsView`** | Solo **rendering** dello snapshot gia' preparato (titolo, sottotitolo, summary compatto opzionale, badge, CTA). |
| **UI** | Card **compatta**, **senza** redesign pesante; posizionamento **§ Card layout placement**. |

---

## Explicit S74-a non-goals

Checklist: cio' che **S74-a** **non** deve fare o introdurre.

- [ ] **Nessun** ramo **`guidedManual`** eseguibile come risultato di questa slice.
- [ ] **Nessun** **`supportsGuidedManualSync = true`**.
- [ ] **Nessuna** chiamata a **`SupabasePullApplyService`** (pull apply) dalla card/summary path.
- [ ] **Nessun** push catalogo.
- [ ] **Nessun** ProductPrice push.
- [ ] **Nessun** outbox **drain** / flush dalla run Release.
- [ ] **Nessun** cleanup / **truncate** / reset outbox.
- [ ] **Nessun** uso di **`SyncEventOutboxDrainService`** nel perimetro S74-a Release.
- [ ] **Nessun** timer, **nessun** **BGTask**, **nessun** Realtime, **nessun** polling.
- [ ] **Nessun** nuovo **schema SwiftData** per questa slice.
- [ ] **Nessuna** migration SQL / **backend** / **Android**.
- [ ] **Nessun** nuovo flusso di **conferma mutativa** (sheet/dialog di conferma apply) — la read-only non richiede mutazioni.
- [ ] **Nessuno** **sheet** per **successo semplice** («tutto ok» gia' chiaro da title/subtitle).
- [ ] **Nessun** summary che **dica o implichi** «**tutto sincronizzato**» / parita' cloud garantita senza verifica esplicita (**D74-04**).

---

## Summary lifecycle

| Momento | Comportamento pianificato |
|---------|---------------------------|
| **Creazione** | Il summary dell'ultimo controllo **nasce** solo **dopo** una run manuale «Controlla cloud» **terminata** con esito mappato nel ViewModel (**non** prima del tap; **non** su idle generico senza esito). |
| **Aggiornamento** | Si **aggiorna** quando termina una **nuova** run read-only con esito diverso (nuovo `RunSummary` / preview summary consolidato nel VM). |
| **Nascosto** | **Nascosto** quando **running** / **checking** domina la card (priorita' al progresso — **§ Summary priority rules**); opzionalmente non mostrare il blocco summary durante run se title/subtitle bastano. |
| **Invalidato** | **Invalidato** (cleared) su **logout**, **cambio account**, **sessione non piu' valida** — nessun messaggio «ultimo controllo» fuori contesto. |
| **Auth / baseline** | Con **blocco auth** o **baseline**, il summary precedente **non** si mostra (sostituito dallo stato gate — vince il blocco). |
| **Dopo run riuscita** | **Mantenuto** dopo una run **completata** con esito stabile, finche' non viene sostituito da una run successiva o invalidazione. |
| **Sostituito da running/auth/baseline** | Qualsiasi stato **running**, **auth**, **baseline** **prende il posto** visivo del summary «storico» finche' attivo. |
| **Cancel** | Copia **neutra** «annullato» — **non** trattato come errore fatale. |
| **Partial vs success** | **Partial** **sostituisce** la lettura «success» se in conflitto per lo stesso framing. |
| **Remote signals vs no-action** | **Remote signals** **sostituiscono** «nessuna azione» per **quello stesso** esito di controllo. |
| **No local pending** | Comunicato come **nessuna modifica locale da inviare** — **non** significa **cloud allineato** / sync completa (**D74-04**). |

**Decisioni fissate:** il summary non e' un log permanente tipo console; e' un **eco controllato** dell'ultima azione utente «Controlla cloud», soggetto a priorita' e invalidazione.

---

## Summary storage policy — planning only

Per **S74-a**, il summary dell'ultimo controllo e' **volatile** e **scoped alla sessione/UI coerente** (non e' dato persistente di prodotto):

- **Non** va salvato in **SwiftData** (nessun **@Model** / entity nuova per il summary Release).
- **Non** va salvato in **UserDefaults** / **AppStorage** (nessuna persistenza cross-launch obbligatoria per questo testo).
- **Non** va scritto su **file** (`FileManager`, cache documenti, ecc.).
- **Non** e' una **cronologia** dei controlli (una sola «ultima» lettura utile).
- **Non** e' un **audit log** ne' traccia tecnica per supporto.
- Vive nella **memoria del ViewModel** / **presentation state** finche' **sessione**, **account** e **gate** (auth/baseline) restano **coerenti** con l'esito mostrato.
- Viene **invalidato** su **logout**, **cambio account**, **sessione non valida**, e quando **auth/baseline** **dominano** lo stato visivo (**§ Summary lifecycle**, **§ Summary priority rules**).
- Se in futuro servisse una **cronologia persistente** controlli cloud → **task separato** con scope, privacy e storage propri; **fuori** da **S74-a**.

---

## Card layout placement — planning only

| Scelta | Dettaglio |
|--------|-----------|
| **Posizione preferita** | **Sotto il subtitle** della card, **sopra le CTA** (primary/secondary), in stile **secondario** (font/collo `secondary` / callout leggero coerente con SwiftUI esistente — da rifinire in EXECUTION). |
| **Alternativa accettabile** | Una **sola riga compatta** sotto il **badge** se il layout attuale della card impone stacking stretto — **solo** se VoiceOver order resta logico (**§ Accessibility**). |
| **Dimensione** | Massimo **1–2 righe**; **nessun** blocco alto, **nessuna tabella**, **nessun elenco tecnico** in S74-a. |
| **Disclosure** | Solo se **§ Compact row vs disclosure vs sheet policy** lo consente. |
| **Sheet** | Solo per **partial** o **blocco** complesso user-facing — **mai** per successo semplice. |

---

## Example final card states — non definitive

Esempi **concettuali** (non stringhe di produzione; non garantiscono parity IT/EN/ES/zh-Hans). Obiettivo: mostrare **coerenza** title/subtitle/summary/CTA senza gergo e senza promessa di sync totale.

| Scenario | Title (concept) | Subtitle (concept) | Summary compatto (concept) | CTA (concept) |
|----------|-----------------|---------------------|------------------------------|---------------|
| **Idle prima di qualsiasi run** | Cloud sync (idle) | Sync manuale, sotto il tuo controllo | *(nessuno / assente)* | Controlla cloud (se capability) |
| **Checking** | Operazione in corso… | Attendi | *(summary nascosto o assente)* | Annulla |
| **Completed no action** | Nessun problema rilevato dal controllo | Nessuna azione automatica | Ultimo controllo: completato. Nessuna azione richiesta. | Controlla cloud / (idle) |
| **Completed with remote signals** | Ci sono elementi da controllare | Nessun invio automatico | Ultimo controllo: risultati da rivedere sul cloud. Nessun invio automatico. | Controlla cloud |
| **No local pending** | Nessuna modifica locale da inviare | *(o footer capability)* | *(omesso se subtitle gia' dice tutto — **D74-15**)* | Controlla cloud |
| **Partial** | Controllo cloud incompleto | Riprova piu' tardi | Ultimo controllo: non completato. | Riprova |
| **Network failed** | Connessione non disponibile | Riprova | Ultimo controllo: non completato (rete). | Riprova |
| **Session failed** | Accesso al cloud necessario | Accedi per continuare | *(opz. omesso se ridondante)* | Accedi |
| **Cancelled** | Operazione annullata | Puoi riprovare quando vuoi | *(opz. neutro, non errore)* | Controlla cloud |

---

## Future mutation summary boundary

Gli stati **mutativi** (applicato, inviato, in coda, saltato con significato di fase, contatori push/apply/drain) restano **solo contratto** per **future slice** (`guidedManual`, **S74-c**, task dedicati).

Per **S74-a** in Release:

- **Non** mostrare «**applicato**» (localmente o remoto).
- **Non** mostrare «**inviato**» al cloud.
- **Non** mostrare «**in coda**» / code operative (nemmeno con metafora ambigua che richiami outbox).
- **Non** mostrare «**saltato**» se suggerisce **fasi** non eseguite / pipeline tecniche.
- **Non** mostrare **contatori** di push / apply / drain / operazioni simili.

Questi elementi potranno essere **abilitati** solo quando **`guidedManual`** sara' **reale** e onesto in un **task separato** con review dedicata — **non** in S74-a.

---

## Summary state matrix — S73-a read-only (vincolante per planning)

*Allineata alla state machine **§ S74-a read-only summary state machine** per EXECUTION; la tabella seguente resta la vista «scenario / condizione» aggregata.*

| Stato utente (logico) | Condizione tecnica (indicativa) | Titolo/summary (concept IT) | Note |
|----------------------|---------------------------------|------------------------------|------|
| **Controllo cloud completato — nessun segnale rilevante** | `RemotePreviewSummary`: complete, no failure, `hasRemoteSignals == false`, non cancellato | «Controllo cloud completato.» + sottotitolo «Nessuna azione richiesta.» | No «cloud aggiornato». |
| **Controllo completato — ci sono differenze / elementi da rivedere** | `hasRemoteSignals == true` | «Ci sono modifiche da controllare» (o variante D74-05) + «Nessun invio automatico.» | Nessun elenco. |
| **Nessuna modifica locale da inviare** | `PrivacyCounts` senza lavoro pendente (aggregato) | «Non risultano modifiche locali da inviare.» | Non usa «tutto sincronizzato». |
| **Controllo cloud incompleto / parziale** | `isPartial` o preview partial/budget | «Controllo cloud incompleto.» + riprova | Allineato **D74-06**. |
| **Errore rete** | `failureCategory == .network` | «Connessione non disponibile.» / «Riprova.» | |
| **Sessione / permessi** | `.permission` | «Accesso al cloud non disponibile.» / Accedi | |
| **Errore tecnico generico** | schema/decode/local/unknown mappati a messaggio unico | «Controllo non completato. Riprova più tardi.» | No stack. |
| **Annullato** | `wasCancelled` | «Controllo annullato.» | |
| **Gia' in corso / occupato** | concurrent / running | «Operazione in corso…» + attendere | CTA disabilitate, non nascoste se gia' mostrate. |

---

## Summary state matrix — futuro run mutativa (solo contratto / planning)

*Slice **S74-c** o task successivo quando `guidedManual` e' reale.*

| Stato utente (concept) | Significato |
|------------------------|-------------|
| **Controllato** | Fase lettura/preview completata senza applicare. |
| **Applicato localmente** | Pull/apply o scrittura SwiftData conforme a policy (futuro). |
| **Inviato al cloud** | Push/drain riuscito (senza dire «RPC» / «outbox» in UI). |
| **Lasciato in coda** | Operazioni ancora da inviare — linguaggio **«Restano invii in sospeso»** o simile, mai «outbox». |
| **Saltato** | Fase saltata per no-work o scelta utente. |
| **Fallito** | Fase terminata in errore retry / non retry. |
| **Parziale** | Parte delle azioni completate. |
| **Bloccato** | Auth, baseline, conflitto policy — messaggio aggregato. |

---

## Mapping tecnico → user-facing (planning)

| Origine | Campi utili | **Non** esporre in Release | Destinazione UX |
|---------|-------------|----------------------------|-----------------|
| `SupabaseManualSyncRunSummary` | `finalState`, `userFacingHeadline`, `countsSnapshot`, `remotePreviewSummary`, `suggestedNextStep` | `executedPhases` / `skippedPhases` come enum grezzo | Tradurre in chiavi summary + badge |
| `SupabaseManualSyncRemotePreviewSummary` | `hasRemoteSignals`, `isPartial`, `wasCancelled`, `recommendedUserMessageKey` | `safeAggregateCounts` **per campo** (solo se in futuro si decide un conteggio **molto** aggregato tipo «molte differenze» — opzionale) | Messaggio primary/secondary |
| `SupabaseManualSyncPhaseOutcome` | `.completed`, `.partial`, `.failed*`, `.cancelled`, `.blocked` | Nome fase `.remotePreview` in UI | Drive categoria summary |
| `SupabaseManualSyncPrivacyCounts` | `hasAnyPendingWork`, conteggi aggregati | singoli ID | Copy pending locale |

---

## Copy guidelines (indicativo — IT / EN / ES / zh-Hans)

*Bozze **non definitive** per parity semantica; stringhe finali in EXECUTION con review copy.*

| Chiave proposta (`options.supabase.manualSync.summary.*`) | IT (indicativo) | EN (indicativo) | ES (indicativo) | zh-Hans (indicativo) |
|------------------------------------------------------------|-----------------|-----------------|-----------------|----------------------|
| `cloudCheck.completed.ok` | Controllo cloud completato. | Cloud check completed. | Revisión en la nube completada. | 云端检查已完成。 |
| `cloudCheck.completed.noAction` | Nessuna azione richiesta. | No action needed. | No se necesita ninguna acción. | 无需任何操作。 |
| `cloudCheck.differences` | Ci sono elementi da controllare sul cloud. | There are items to review on the cloud. | Hay elementos que revisar en la nube. | 云端有需要核对的项目。 |
| `cloudCheck.noAutoSend` | Nessun invio automatico. | Nothing is sent automatically. | No se envía nada automáticamente. | 不会自动发送任何内容。 |
| `local.noPending` | Non risultano modifiche locali da inviare. | No local changes waiting to send. | No hay cambios locales pendientes de enviar. | 没有待发送的本地更改。 |
| `cloudCheck.incomplete` | Controllo cloud incompleto. | Cloud check incomplete. | Revisión en la nube incompleta. | 云端检查未完成。 |
| `cloudCheck.cancelled` | Controllo annullato. | Check cancelled. | Revisión cancelada. | 检查已取消。 |
| `network` | Connessione non disponibile. Riprova. | Connection unavailable. Try again. | Sin conexión. Inténtalo de nuevo. | 网络不可用。请重试。 |
| `session` | Accesso al cloud necessario. | Cloud access required. | Se necesita acceso a la nube. | 需要访问云端。 |
| `generic` | Controllo non completato. Riprova. | Check not completed. Try again. | Revisión no completada. Inténtalo de nuevo. | 检查未完成。请重试。 |

**Parity:** **ES** / **zh-Hans** devono restare allineate a IT/EN per significato (**TASK-072**); rifinitura linguistica in EXECUTION.

---

## Error taxonomy privacy-safe (Release)

| Categoria interna | Messaggio utente (famiglia) | Cosa non mostrare |
|-------------------|-------------------------------|-------------------|
| Rete | Connessione / timeout — generic | host, codice HTTP |
| Sessione / permessi | Accedi / permessi insufficienti | RLS, ruoli |
| Dati / formato | Problema temporaneo — riprovare | decode, stack |
| Locale snapshot | Messaggio generico | path DB |
| Annullamento | Operazione annullata | task id |

**Vietato:** barcode, nome prodotto, supplier/category **non come statistica aggregata esplicitamente approvata**, payload, liste ID.

---

## Accessibility checklist (execution futura)

- [ ] VoiceOver: ordine logico titolo → sottotitolo → eventuale riga summary → badge → CTA.
- [ ] Dynamic Type: summary compatto non trabocca (truncation sensata o sheet se necessario).
- [ ] Contrasto badge e stato (**D72-26**).
- [ ] Stato disabilitato con **hint** che spiega *perche'* (non solo "dimmed").

---

## File iOS probabilmente da toccare in execution futura

- `SupabaseManualSyncViewModel.swift` — mapping centralizzato verso summary presentazionale.
- Eventuale nuovo file **`SupabaseManualSyncUserFacingSummary.swift`** (nome indicativo) — solo tipi Sendable / enum UI.
- `SupabaseManualSyncCoordinatorModels.swift` — solo se servono estensioni non-breaking (preferire mapper separato).
- `SupabaseManualSyncReleaseFactory.swift` — solo se DI aggiuntiva minima.
- `OptionsView.swift` / componente card — solo rendering summary (disclosure/sheet), **non** regole.
- `it.lproj` / `en.lproj` / `es.lproj` / `zh-Hans.lproj` `Localizable.strings` — chiavi summary.
- `SupabaseManualSyncViewModelTests.swift`, `SupabaseManualSyncReleaseUITests.swift`, `SupabaseManualSyncRemotePreviewTests.swift` — estensioni test.

---

## File da NON toccare (salvo review esplicita)

- `project.pbxproj` (salvo aggiunta file inevitabile in execution — non in questo planning).
- Backend Supabase, SQL, Android.
- `SyncEventOutbox*`, drain DEBUG card (perimetro separato).
- Servizi che introducono mutazioni non richieste dalla slice attiva.

---

## Micro-slice execution futura (consigliate)

| Slice | Contenuto | Gate |
|-------|-----------|------|
| **S74-a** | Summary read-only post **«Controlla cloud»**: modello presentazionale + mapping + card compatta (**§ hierarchy**, **D74-13**, state machine **S74-a**); tests ViewModel + Release UI; **read-only**, **no** `guidedManual`, **no** mutazioni. | Primo merge consigliato dopo override su **solo S74-a**. |
| **S74-b** | Localizzazioni complete IT/EN/ES/zh-Hans + test no-jargon / grep anti-scope esteso. | Dopo S74-a o nello stesso merge se copy stabile. |
| **S74-c** | Summary per run **mutativa** futura (`guidedManual`) — stati contratto TASK-074 mappati da fasi reali. | Solo quando **supportsGuidedManualSync** esiste ed e' onesto. |
| **S74-d** | Polish UX/accessibility (disclosure/sheet, Dynamic Type, hints). | Dopo contenuto funzionale. |

---

## Test matrix (futura execution)

| ID | Tipo | Cosa verificare |
|----|------|-----------------|
| **T74-01** | **STATIC / ViewModel** | Mapping `UserFacingSummary` / presentation per ogni riga della state matrix S73-a. |
| **T74-02** | **STATIC / UI** | `SupabaseManualSyncReleaseUITests` — testi localizzati senza jargon vietato. |
| **T74-03** | **STATIC / l10n** | Parita' chiavi `summary.*` quattro lingue (script duplicati / plutil). |
| **T74-04** | **STATIC** | Scenario read-only: nessuna mutazione datastore verificata nei test di perimetro TASK-073/074. |
| **T74-05** | **STATIC** | Partial / error / cancel / busy — snapshot UI coerenti. |
| **T74-06** | **Grep** | Anti-scope termini vietati in `options.supabase.manualSync.*`. |
| **T74-07** | **STATIC / copy** | **No duplicate copy:** titolo, sottotitolo e summary compact **non** ripetono la stessa frase (**D74-13**); se ridondante, summary assente. |
| **T74-08** | **STATIC / ViewModel** | **Auth/baseline priority:** quando gate auth o baseline attivo, summary «ultimo controllo» precedente **non** resta visibile (stale nascosto). |
| **T74-09** | **STATIC / ViewModel** | **Logout / cambio sessione:** invalidazione o clearing del summary ultimo controllo; nessun messaggio stale fuori contesto account. |
| **T74-10** | **STATIC** | **Partial wins over success:** se entrambi applicabili, stato presentato = partial / incompleto, non success. |
| **T74-11** | **STATIC / UI** | **Remote signals:** copy **senza** conteggi identificativi, **senza** ID/barcode; solo messaggi famiglia approvati. |
| **T74-12** | **STATIC / architettura** | **`OptionsView`** e card = **solo rendering** (**D74-14**); logica summary solo ViewModel/helper — test devono fallire se la vista introduce branching business sul summary. |
| **T74-13** | **STATIC / persistenza** | Il summary **non** e' persistito in **SwiftData**, **UserDefaults**, ne' **file**; coerente con **§ Summary storage policy**. |
| **T74-14** | **STATIC / l10n** | Nessuna stringa `summary.*` / card Release usa «**tutto sincronizzato**» o equivalente **troppo forte** (IT/EN/ES/zh-Hans: es. *fully synced*, *todo sincronizado*, *全部同步*) che implichi parita' cloud totale. |
| **T74-15** | **STATIC / ViewModel** | Logout / cambio account **nasconde** o **azzera** il summary precedente (coerenza con **T74-09**, **§ Summary lifecycle**). |
| **T74-16** | **STATIC / OptionsView** | `OptionsView` **non** importa ne' usa **DTO** / tipi summary tecnici / preview raw; solo snapshot gia' preparato. |
| **T74-17** | **STATIC / l10n regressione** | Chiavi **`summary.*`** sono **additive**; `state.*` esistenti **non** rotture di massa — snapshot o test parita' (**D74-17**). |

---

## Grep anti-scope (suggerito per execution / review)

```bash
# Esempi — adattare path al repo
rg -n "outbox|drain|RPC|DTO|SyncPreview|payload|sync_events" iOSMerchandiseControl --glob "*.swift" | rg "OptionsView|manualSync"
rg "options\.supabase\.manualSync" iOSMerchandiseControl -g "*.strings" -n

# Scope mutativo / live — deve restare assente da merge S74-a read-only
rg -n "supportsGuidedManualSync\s*=\s*true" iOSMerchandiseControl --glob "*.swift"
rg -n "SupabasePullApplyService" iOSMerchandiseControl --glob "*.swift"
rg -n "SyncEventOutboxDrainService" iOSMerchandiseControl --glob "*.swift"
rg -n "ProductPrice" iOSMerchandiseControl/iOSMerchandiseControl --glob "*ManualSync*" --glob "*Release*" 2>/dev/null || true
rg -n "\bpush\b" iOSMerchandiseControl/iOSMerchandiseControl --glob "*OptionsView*" --glob "*ManualSync*"

# SDK diretto nella superficie summary/card (fail se introdotto in S74-a senza motivo)
rg -n "SupabaseClient" iOSMerchandiseControl/iOSMerchandiseControl --glob "*OptionsView*"
rg -n "SupabaseClient" iOSMerchandiseControl/iOSMerchandiseControl --glob "*SupabaseManualSyncViewModel*"

# Chiavi summary — vietato jargon tecnico nelle stringhe utente
rg "options\.supabase\.manualSync\.summary\." iOSMerchandiseControl -g "*.strings" -n

# Persistenza / storage — non introdurre in S74-a per il summary testuale
rg -n "UserDefaults" iOSMerchandiseControl/iOSMerchandiseControl --glob "SupabaseManualSync*.swift"
rg -n "@Model|SwiftData" iOSMerchandiseControl/iOSMerchandiseControl --glob "*ManualSync*" --glob "*Summary*" 2>/dev/null || true
rg -n "FileManager|write\\(|\\.write\\(" iOSMerchandiseControl/iOSMerchandiseControl --glob "SupabaseManualSync*.swift"

# Copy fuorviante «tutto sincronizzato» / equivalenti (Release manual sync)
rg -n "tutto sincronizzato|fully synced|todo sincronizado|全部同步|Fully synced|全.?同步" iOSMerchandiseControl -g "*.strings" | rg -i "manualSync|supabase"

# DTO / preview raw nella vista
rg -n "SyncPreview|SupabaseManualSyncRemotePreviewSummary|SupabaseManualSyncRunSummary" iOSMerchandiseControl/iOSMerchandiseControl --glob "*OptionsView*"
```

**Controlli pianificati aggiuntivi (interpretazione esito):**

- Occorrenze **`supportsGuidedManualSync = true`** nel perimetro Release/sync manuale → **assenti** in S74-a.
- Riferimenti impropri a **`SupabasePullApplyService`**, **`SyncEventOutboxDrainService`**, push **ProductPrice** / **push** generico nel diff **S74-a** read-only → **fallimento** review salvo task separato.
- **`SupabaseClient`** in **`OptionsView`** / ViewModel summary: vietato pattern diretti nella card (**allineamento** TASK-072/073).
- Stringhe **`options.supabase.manualSync.summary.*`**: nessun termine **outbox**, **drain**, **RPC**, **DTO**, **payload**, **SyncPreview** negli **valori** localizzati.
- **Nessun** uso di **UserDefaults** / **FileManager** / nuove **entity SwiftData** per **persistere** il testo summary nel perimetro **S74-a**.
- **Import** di tipi **DTO** / **RunSummary** / **preview raw** in **`OptionsView`**: **vietato** (solo presentation pronta).

Fallimento review se stringhe **Release** visibili all'utente contengono termini vietati (**D72-19**, **D74-11**).

---

## Rischi

| Rischio | Mitigazione |
|---------|-------------|
| Overlap copy titolo card vs summary | Un solo «source of truth» nel ViewModel; chiavi distinti `state.*` vs `summary.*` con regola di priorita'. |
| **Duplicate copy** title/subtitle/summary | **D74-13** + test **T74-07**; omettere summary se inutile. |
| Confusione «technical» vs «differenze cloud» | Documentare mapping esplicito (**D74-05**) e test stringa. |
| Scope creep mutativo | Tenere **S74-c** separato finche' guided non esiste. |
| Inflazione stringhe | Summary **una riga**; sheet solo se necessario. |
| Summary stale dopo logout/sessione | **Summary priority rules** §7 + test **T74-08** / **T74-09**. |
| Persistenza accidentale summary | **§ Summary storage policy** + **T74-13**, grep **UserDefaults** / **@Model** / file. |

---

## Execution safety checklist for future S74-a

Checklist **breve** pre-merge (executor / reviewer) — **non** sostituisce i criteri completi.

- [ ] **TASK-074 planning v4** (o v3+v4) **review approved**.
- [ ] **User override** esplicito per **S74-a** read-only.
- [ ] **TASK-075** resta **TODO** nel tracking (nessun avvio parallelo non autorizzato).
- [ ] **`supportsGuidedManualSync`** resta **false** nel perimetro Release S74-a.
- [ ] **Nessun** apply / push / drain / ProductPrice push / outbox path nel diff S74-a.
- [ ] Summary **volatile** — **nessuna** persistenza SwiftData/UserDefaults/file (**§ Summary storage policy**).
- [ ] **`OptionsView`** = **solo rendering** (**D74-14**).
- [ ] **Localizable** **IT / EN / ES / zh-Hans** per chiavi toccate / nuove `summary.*`.
- [ ] **Grep anti-scope** + anti-persistenza (§ Grep) eseguiti o documentati se l'ambiente fallisce.
- [ ] **Test** mirati ViewModel / UI / l10n se l'ambiente lo permette (**T74-01…17**).

---

## Definition of Ready (execution futura)

- [ ] Review planning TASK-074 **v4 APPROVED** (o **v3** + accettazione esplicita paragrafi **v4**: storage, **D74-16/17**, checklist, test **T74-13…17**).
- [ ] **User override** esplicito per **S74-a** **read-only summary** soltanto (nessuna mutazione).
- [ ] Conferma scritta che **S74-a** = **solo** summary read-only + UI compact — **non** guidedManual / **non** `supportsGuidedManualSync`.
- [ ] **File Swift target** per S74-a individuati e condivisi (tipicamente ViewModel, eventuale helper, `Localizable`, card subview, test elencati in § File iOS probabilmente).
- [ ] **Test / snapshot / copy** minimi per S74-a identificati (mapping VM, **T74-07** no duplicate, **T74-08…15**, persistenza **T74-13**, parity chiavi nuove).
- [ ] **Grep anti-mutazione** (§ Grep anti-scope) pronto come checklist pre-merge.
- [ ] **Nessun altro task** nel repo in **ACTIVE / EXECUTION** sulle stesse superfici (coerenza workflow progetto).
- [ ] Ca mapping S73-a / S74-a allineati con prodotto (**D74-03** … **D74-06**, **D74-13**, **D74-14/15**, **D74-16/17**).

---

## Definition of Done — planning (questo documento)

- [x] Contratto summary S73-a e futuro mutativo documentati.
- [x] Taxonomy error privacy-safe.
- [x] Micro-slice e test matrix presenti (**v2:** T74-07…12, hierarchy, state machine S74-a, priority rules).
- [x] Handoff verso review planning (**v2**).
- [x] **v3:** **S74-a execution brief** presente.
- [x] **v3:** **Explicit S74-a non-goals** presente.
- [x] **v3:** **Summary lifecycle** definito.
- [x] **v3:** **Card layout placement** definito.
- [x] **v3:** **Example final card states** presenti.
- [x] **v3:** **D74-14** (OptionsView rendering-only) e **D74-15** (copy migration conservativa) presenti.
- [x] **v3:** **Future mutation summary boundary** presente.
- [x] **v3:** Conferma **nessuna** EXECUTION Swift nel planning; handoff **v3**.
- [x] **v4:** **Summary storage policy** (volatile/session-scoped); **D74-16** / **D74-17**; **Execution safety checklist**; **Planning review checklist**; test **T74-13…17** + grep anti-persistenza; handoff **v4**.

---

## Criteri di accettazione (planning TASK-074)

| ID | Criterio | Stato |
|----|----------|--------|
| **CA74-01** | File task creato. | [x] |
| **CA74-02** | `MASTER-PLAN` aggiornato a **ACTIVE** / **TASK-074 ACTIVE / PLANNING**. | [x] |
| **CA74-03** | Summary states definiti per **S73-a read-only** (matrice). | [x] |
| **CA74-04** | Mapping tecnico → UX definito **senza** raw DTO/SyncPreview in Release. | [x] |
| **CA74-05** | Policy **no-jargon** Release definita (**D74-11** + riferimento D72-19). | [x] |
| **CA74-06** | Localizzazione IT/EN/ES/zh-Hans **pianificata** (chiavi + linee guida). | [x] |
| **CA74-07** | Test matrix e grep anti-scope presenti. | [x] |
| **CA74-08** | **TASK-075** resta **TODO** nel MASTER-PLAN. | [x] |
| **CA74-09** | Nessuna execution Swift autorizzata da questo turno. | [x] |
| **CA74-10** | Handoff finale **READY FOR PLANNING REVIEW v4**, **NON READY FOR EXECUTION**. | [x] |
| **CA74-11** | **Presentation hierarchy** (title / subtitle / badge / summary / disclosure·sheet) definita. | [x] |
| **CA74-12** | Policy **No duplicate copy** (**D74-13**) definita. | [x] |
| **CA74-13** | **Proposed presentation model — planning only** presente (campi indicativi, vincoli). | [x] |
| **CA74-14** | **S74-a read-only summary state machine** (stati minimi + colonne) presente. | [x] |
| **CA74-15** | Policy **Compact row vs disclosure vs sheet** presente. | [x] |
| **CA74-16** | Copy indicativa **ES** e **zh-Hans** in **Copy guidelines** (parity semantica). | [x] |
| **CA74-17** | **Summary priority rules** presenti. | [x] |
| **CA74-18** | Il planning conferma che **S74-a** resta **read-only** e **non** abilita `guidedManual` / mutazioni. | [x] |
| **CA74-19** | Sezione **S74-a execution brief — planning only** presente. | [x] |
| **CA74-20** | Checklist **Explicit S74-a non-goals** presente. | [x] |
| **CA74-21** | **Summary lifecycle** definito. | [x] |
| **CA74-22** | **Card layout placement — planning only** definito. | [x] |
| **CA74-23** | Decisione **D74-14** (**OptionsView** rendering-only) presente. | [x] |
| **CA74-24** | Decisione **D74-15** (existing copy migration conservative) presente. | [x] |
| **CA74-25** | Sezione **Example final card states** presente. | [x] |
| **CA74-26** | Sezione **Future mutation summary boundary** presente. | [x] |
| **CA74-27** | **v3** conferma solo **markdown** nel planning e **nessuna** EXECUTION Swift autorizzata da questo documento. | [x] |
| **CA74-28** | **Summary storage policy** (volatile / session-scoped) definita. | [x] |
| **CA74-29** | Decisione **D74-16** (**Summary is ephemeral, not history**) presente. | [x] |
| **CA74-30** | Decisione **D74-17** (**Summary localization is additive**) presente. | [x] |
| **CA74-31** | **Execution safety checklist** per S74-a futura presente. | [x] |
| **CA74-32** | **Planning review checklist** (reviewer) presente. | [x] |
| **CA74-33** | Test **T74-13…17** e grep anti-persistenza / anti-«tutto sincronizzato» presenti. | [x] |
| **CA74-34** | **v4** conferma **TASK-074** **ACTIVE / PLANNING**, **NON READY FOR EXECUTION** (nessuna promozione a execution da questo passaggio). | [x] |

---

## Planning review checklist (Claude reviewer)

Checklist per **review** del planning prima di autorizzare **S74-a**:

- [ ] Il piano resta **read-only** per **S74-a** (nessuna mutazione cloud/locale dalla card).
- [ ] **Non** introduce apply / push / drain / ProductPrice / outbox nel perimetro documentato.
- [ ] **Non** promette «**tutto sincronizzato**» / sync completa implicita.
- [ ] **Non** mostra **jargon tecnico** in Release (`options.supabase.manualSync.*`).
- [ ] **Non** introduce **storage persistente** per il summary testuale (**§ Summary storage policy**).
- [ ] **Non** trasforma **`OptionsView`** in contenitore di **logica business** (**D74-14**).
- [ ] UX **coerente** con la **card esistente** (gerarchia, layout, no redesign pesante).
- [ ] **Micro-slice** execution futura (**S74-a…d**) ancora chiara e **non** contradetta da v4.
- [ ] Criteri **testabili** (**T74-xx**, grep, ephemeral, additive l10n).

---

## Planning (Claude)

### Analisi

Dopo **TASK-073 S73-a**, la Release puo' eseguire un controllo cloud reale read-only. Il coordinatore produce gia' un `RunSummary` ricco; il ViewModel traduce in `presentationKind` e chiavi localization. Manca una **superficie di summary finale** esplicitamente progettata per **comprensione utente** (cosa e' stato controllato / cosa resta / cosa non e' stato inviato), e un **contratto** per le fasi mutative future senza implementarle. Il perfezionamento **v2** definisce gerarchia visiva, **no duplicate copy**, modello presentazionale indicativo, **state machine S74-a**, policy compact/disclosure/sheet, **priority rules**, copy **ES/zh-Hans** e test/grep estesi. Il perfezionamento **v4** chiarisce **storage volatile** (**§ Summary storage policy**), **D74-16/17**, checklist **pre-execution** e **review**, test/grep **anti-persistenza** — per ridurre ambiguita' in una futura **S74-a**.

### Approccio proposto

1. Introdurre in execution (S74-a) un **modello presentazionale** dedicato (nome indicativo `SupabaseManualSyncUserFacingSummary`) derivato da summary tecnici tramite **funzione pura testabile**, coerente con **§ Proposed presentation model** e **§ S74-a read-only summary state machine**.
2. Rispettare **§ Presentation hierarchy** e **D74-13**: summary compatto **solo** se aggiunge informazione; title/subtitle primari.
3. Applicare **§ Summary priority rules** e **§ Compact row vs disclosure vs sheet policy** per evitare stale summary e UI pesante.
4. Seguire **§ S74-a execution brief**, **§ Explicit S74-a non-goals**, **§ Summary lifecycle**, **§ Summary storage policy**, **§ Card layout placement**, **§ Future mutation summary boundary**; **`OptionsView`** solo rendering (**D74-14**); migrazione copy **conservativa** (**D74-15**); summary **ephemero** (**D74-16**); l10n **additiva** (**D74-17**).
5. Mantenere la card compatta; disclosure/sheet solo dove la policy lo consente.
6. Estendere `Localizable` con namespace `summary.*` a quattro lingue (vedi **Copy guidelines** con ES/zh-Hans).
7. Aggiornare test (**T74-01…17**) + grep esteso (perimetro S74-a read-only, anti-persistenza, anti-copy fuorviante).

### Handoff post-planning

- **Stato handoff:** **READY FOR PLANNING REVIEW v4**
- **Execution:** **NON READY FOR EXECUTION** — nessuna modifica Swift autorizzata finche' la review planning non approva e l'utente non autorizza **S74-a** read-only.
- **Prossima azione consigliata:** review planning **v4** del documento TASK-074; poi eventuale **user override** esplicito solo per execution **S74-a** (summary read-only, senza `guidedManual`).

---

## Execution (Codex)

### 2026-05-08 10:12 -0400 — EXECUTION S74-a avviata

#### Stato iniziale

- Override utente esplicito ricevuto per avviare **S74-a**: summary read-only compatto post **«Controlla cloud»**.
- Tracking promosso a **TASK-074 ACTIVE / EXECUTION**, responsabile **Cursor / Executor**.
- **TASK-073** resta ultimo completato **DONE / Chiusura**.
- **TASK-075** resta **TODO**.
- Nessun codice Swift modificato in questo step di tracking iniziale.

### 2026-05-08 10:23 -0400 — EXECUTION S74-a implementata

#### Obiettivo compreso

Aggiungere alla card Release **Sincronizzazione cloud** un summary compatto, read-only, user-facing e volatile dopo l'esito esplicito di **«Controlla cloud»**, senza mutazioni, senza persistenza, senza raw DTO/`SyncPreview` in `OptionsView` e senza promettere «tutto sincronizzato».

#### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-074-supabase-manual-sync-user-facing-summary-ios.md`
- `docs/TASKS/TASK-073-supabase-manual-sync-live-wiring-ios.md`
- `docs/TASKS/TASK-072-supabase-release-cta-controlla-cloud-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests.swift`

#### Piano minimo

1. Estendere il presentation state del ViewModel con un summary user-facing gia' localizzato e testabile.
2. Mappare solo `RunSummary` / `RemotePreviewSummary` gia' esistenti, senza nuovi fetch/servizi.
3. Renderizzare in `OptionsView` solo il summary gia' preparato, sotto subtitle e sopra CTA.
4. Aggiungere chiavi additive `options.supabase.manualSync.summary.*` in IT/EN/ES/zh-Hans.
5. Coprire mapping, no-duplicate copy, hidden su running/auth/baseline, partial priority, privacy/no counts, no-persistenza e grep anti-scope.

#### Modifiche fatte

- `SupabaseManualSyncViewModel`:
  - aggiunti `SupabaseManualSyncUserFacingSummaryKind` e `SupabaseManualSyncUserFacingSummary`, `Sendable`/`Equatable`;
  - `SupabaseManualSyncPresentationState` ora espone `userFacingSummary`;
  - mapping summary centralizzato nel ViewModel da `SupabaseManualSyncRunSummary` / `SupabaseManualSyncRemotePreviewSummary`;
  - priorita' applicate: running/auth/baseline nascondono summary, partial remoto vince su success, remote signals vincono su no-action, no local pending non promette cloud allineato;
  - summary non ridondante: se uguale a title/subtitle viene omesso.
- `OptionsView`:
  - rendering-only del `presentation.userFacingSummary` come testo compatto max 2 righe, sotto subtitle e sopra CTA;
  - nessun branching su esiti tecnici, DTO, `RunSummary`, `RemotePreviewSummary` o `SyncPreview`.
- `Localizable.strings`:
  - aggiunte chiavi additive `options.supabase.manualSync.summary.*` in IT/EN/ES/zh-Hans.
- Test:
  - mapping ViewModel per no-action, segnali remoti, no local pending, partial, network/session/generic/cancelled;
  - no duplicate copy;
  - running/auth/baseline nascondono summary precedente;
  - remote signals senza ID/conteggi identificativi;
  - card Release rendering-only;
  - summary non persistito in ViewModel/card.

#### Volutamente lasciato fuori

- Nessun `guidedManual` eseguibile.
- Nessun `supportsGuidedManualSync = true`.
- Nessun `SupabasePullApplyService` nel percorso summary/card Release.
- Nessun push catalogo, nessun ProductPrice push, nessun outbox drain/cleanup/reset.
- Nessun `SyncEventOutboxDrainService` nel perimetro S74-a Release.
- Nessun Timer/BGTask/Realtime/polling.
- Nessun nuovo schema SwiftData, nessun `UserDefaults`/`AppStorage`/`FileManager` per il summary.
- Nessun backend/Supabase SQL/migration/Android.
- Nessun nuovo flusso di conferma mutativa, nessuna sheet per successo semplice, nessuna cronologia/audit log.

#### Check eseguiti

- ✅ ESEGUITO — Build Debug Simulator: `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release Simulator finale: `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — XCTest mirati ViewModel / Release UI / RemotePreview: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests`: **54 test**, **0 failure**.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` sui quattro `Localizable.strings`: PASS.
- ✅ ESEGUITO — duplicate localization keys `options.supabase.manualSync.*`: PASS.
- ✅ ESEGUITO — Nessun warning nuovo nei file S74-a verificato da build/test; warning residui preesistenti/out-of-scope in AppIntents metadata, `SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`.
- ✅ ESEGUITO — Modifiche coerenti con planning S74-a: solo summary read-only compatto, volatile, localizzato e rendering-only.
- ✅ ESEGUITO — Criteri S74-a verificati staticamente/test: no mutazioni, no persistenza summary, no raw `SyncPreview` nella card Release, no copy «tutto sincronizzato» o equivalenti nelle stringhe manual sync.
- ⚠️ NON ESEGUIBILE — Test manuale Simulator/UX visivo non eseguito perche' non richiesto esplicitamente dal task/utente; coperti build, XCTest e verifiche statiche.

#### Grep anti-scope

- ✅ `rg -n "supportsGuidedManualSync\\s*[:=]\\s*true" iOSMerchandiseControl --glob "*.swift"`: zero match.
- ✅ `rg -n "SupabasePullApplyService|SyncEventOutboxDrainService|drain\\(|ProductPrice|\\bpush\\b" iOSMerchandiseControl --glob "*SupabaseManualSync*.swift" --glob "*OptionsView.swift"`: match preesistenti/ammessi fuori card Release su area ProductPrice DEBUG/apply/push e su simulatore concettuale `simulateProductPricePushPhase`; nessuna nuova mutazione S74-a.
- ✅ `rg -n "BGTask|Timer|Realtime|polling|poll\\(|BackgroundTasks" iOSMerchandiseControl --glob "*SupabaseManualSync*.swift" --glob "*OptionsView.swift"`: zero match.
- ✅ `rg -n "SupabaseClient|\\.rpc\\(|\\.channel\\(" iOSMerchandiseControl --glob "*SupabaseManualSync*.swift" --glob "*OptionsView.swift"`: zero match.
- ✅ `rg -n "SyncPreview|outbox|drain|sync_events|payload|retryable|\\bRPC\\b|\\bDTO\\b" iOSMerchandiseControl/*.lproj/Localizable.strings`: match preesistenti/ammessi su diagnostica/debug Supabase (`options.supabase.diagnostic.*`, `options.supabase.syncEvents*`, `options.supabase.syncEventsOutbox*`); zero match sulle chiavi `options.supabase.manualSync.summary.*`.
- ✅ `rg -n "UserDefaults|AppStorage|FileManager|\\.write\\(" iOSMerchandiseControl --glob "*SupabaseManualSync*.swift" --glob "*OptionsView.swift"`: match preesistenti in `OptionsView` per preferenze app/auth (`appTheme`, `appLanguage`, `supabaseLastLinkedUserID`); scan mirato su ViewModel + Release card summary: zero match.
- ✅ `rg -n "tutto sincronizzato|fully synced|todo sincronizado|全部同步|全.?同步" iOSMerchandiseControl -g "*.strings"`: zero match.
- ✅ `rg -n "SyncPreview|SupabaseManualSyncRunSummary|SupabaseManualSyncRemotePreviewSummary" iOSMerchandiseControl --glob "*OptionsView.swift"`: match preesistenti fuori card Release nella superficie pull/apply preview; scan/test mirato sulla `SupabaseManualSyncReleaseCard`: zero match.

#### Rischi rimasti

- Il summary e' staticamente/testato ma non verificato con smoke manuale nel Simulator.
- In `OptionsView` restano superfici DEBUG/ProductPrice/pull-apply preesistenti che producono match nei grep ampi; non sono state toccate per non allargare lo scope.
- La fase resta **ACTIVE / EXECUTION** per istruzione esplicita dell'utente; review/chiusura non avviate e **TASK-074 NON DONE**.

#### Aggiornamenti file di tracking

- `docs/TASKS/TASK-074-supabase-manual-sync-user-facing-summary-ios.md`: compilata solo sezione **Execution** + campi globali consentiti; Review/Fix non compilate.
- `docs/MASTER-PLAN.md`: aggiornato task attivo **TASK-074 ACTIVE / EXECUTION**, slice corrente **S74-a**, ultimo completato **TASK-073 DONE**, **TASK-075 TODO**.

#### Handoff post-execution

- **Stato handoff:** S74-a implementata e verificata; pronta per review, ma tracking mantenuto **ACTIVE / EXECUTION** per richiesta esplicita dell'utente in questo turno.
- **Prossimo responsabile consigliato:** Claude / Reviewer.
- **TASK-074:** **ACTIVE / EXECUTION S74-a**, **NON DONE**.

---

## Review (Claude)

### 2026-05-08 10:37 -0400 — REVIEW S74-a (user override, Codex reviewer+fixer)

#### Verdetto

**CHANGES_APPLIED / APPROVED** — S74-a rispetta il perimetro read-only e viene chiusa **DONE / Chiusura**.

#### Problemi trovati

- **Tracking incoerente / fuorviante:** `MASTER-PLAN` aveva il riepilogo alto aggiornato a **ACTIVE / EXECUTION**, ma la sezione **Workflow task attivo** era rimasta su **ACTIVE / PLANNING** con responsabile **Claude / Planner**.
- **Nota autorizzazioni TASK-074 troppo assoluta:** la nota iniziale dichiarava ancora il task come **solo PLANNING**, senza chiarire che l'execution **S74-a** era poi stata autorizzata con override utente.

#### Esito review architetturale

- `SupabaseManualSyncUserFacingSummaryKind` / `SupabaseManualSyncUserFacingSummary` sono piccoli, presentazionali, `Sendable` / `Equatable` e testabili.
- Il mapping `RunSummary` / `RemotePreviewSummary` / counts → summary user-facing e' centralizzato in `SupabaseManualSyncViewModel`.
- `OptionsView` / `SupabaseManualSyncReleaseCard` renderizzano solo `presentation.userFacingSummary?.message`; nessun mapping tecnico, error taxonomy, DTO o branch business sul summary nella view.
- Nessun `SupabaseClient`, `.rpc`, `.channel`, nuovo servizio remoto, singleton globale o accoppiamento con coordinator/servizi remoti introdotto dalla slice.
- Nessuna persistenza del summary in SwiftData, `UserDefaults`, `AppStorage`, `FileManager` o file.

#### Esito review UX/UI

- Summary posizionato sotto subtitle e sopra CTA, con stile secondario `.caption`, massimo 2 righe.
- Nessun redesign, nessuna sheet per successo semplice, nessuna duplicazione pesante di title/subtitle.
- Summary nascosto in running/auth/baseline; account/logout gestiti dalla card con reset presentation gia' esistente.
- Partial/incomplete vince su success; segnali remoti vincono su no-action; pending locale zero non promette cloud allineato.
- Copy semplice e non tecnico nelle quattro lingue; nessuna promessa «tutto sincronizzato» o equivalente forte.

#### Esito review read-only / anti-scope

- Confermati: nessun `guidedManual` eseguibile, nessun `supportsGuidedManualSync = true`, nessun apply/push/drain/ProductPrice push/outbox cleanup, nessun Timer/BGTask/Realtime/polling.
- Confermati: nessun backend/Supabase SQL/migration/Android, nessun nuovo schema SwiftData, nessun `project.pbxproj`.
- I match grep ampi su `ProductPrice`, `SupabasePullApplyService`, `SyncPreview`, `outbox` e `AppStorage` sono preesistenti/out-of-scope o DEBUG/diagnostica fuori dalla card Release summary.

#### Esito review localizzazioni

- Chiavi additive `options.supabase.manualSync.summary.*` presenti in IT/EN/ES/zh-Hans.
- Nessuna riscrittura massiva di `state.*`.
- Parity semantica verificata; nessun jargon tecnico nelle nuove chiavi summary.
- `plutil -lint` PASS sui quattro `Localizable.strings`; duplicate key check coperto dagli XCTest statici.

#### Esito review test

- Coperti: no-action, remote signals, no local pending, partial/incomplete, network/session/generic/cancelled, no duplicate copy, running/auth/baseline, privacy/no ID/conteggi, OptionsView rendering-only, summary non persistito, no «tutto sincronizzato».
- Nessun test essenziale mancante rilevato nel pattern attuale.

#### Check eseguiti

- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` IT/EN/ES/zh-Hans: PASS.
- ✅ ESEGUITO — XCTest mirati ViewModel / Release UI / RemotePreview: `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -parallel-testing-enabled NO -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests`: **54 test**, **0 failure**.
- ✅ ESEGUITO — Build Debug Simulator: `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release Simulator: `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo nei file S74-a; warning residui preesistenti/out-of-scope in AppIntents metadata, `SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`.
- ✅ ESEGUITO — Grep anti-scope richiesti: PASS; match residui classificati preesistenti/out-of-scope o DEBUG/diagnostica fuori dal path Release summary.

#### Rischi residui

- Smoke manuale Simulator della card non eseguito; non richiesto esplicitamente per la chiusura e coperto da build/XCTest/static review.
- In `OptionsView` restano superfici DEBUG/ProductPrice/pull-apply storiche che producono match nei grep ampi; non sono state toccate per evitare scope creep.

---

## Fix (Codex)

### 2026-05-08 10:37 -0400 — FIX documentale / tracking

#### Modifiche fatte

- Chiarita la **Nota autorizzazioni (TASK-074)**: lo stato planning-only resta storico, ma S74-a e' stata eseguita e revisionata con override utente.
- Compilata la sezione **Review (Claude)** con esito, problemi trovati, check e classificazione grep.
- Aggiornati i campi globali del file task a **DONE / Chiusura**.
- `MASTER-PLAN` riallineato a progetto **IDLE**, nessun task attivo, ultimo completato **TASK-074 DONE / Chiusura**, **TASK-075 TODO**.

#### Handoff post-fix

- Fix documentale/tracking verificato con `git diff --check`.
- Task chiuso **DONE / Chiusura** su override utente.

---

## Chiusura

TASK-074 **DONE / Chiusura**.

- Esito: **CHANGES_APPLIED / APPROVED** dopo review tecnica severa.
- Slice chiusa: **S74-a** — summary read-only compatto post **«Controlla cloud»**.
- File modificati da TASK-074: `SupabaseManualSyncViewModel.swift`, `OptionsView.swift`, `Localizable.strings` IT/EN/ES/zh-Hans, `SupabaseManualSyncViewModelTests.swift`, `SupabaseManualSyncReleaseUITests.swift`, questo file task e `docs/MASTER-PLAN.md`.
- Conferme finali: summary volatile, rendering-only in `OptionsView`, mapping nel ViewModel, nessuna mutazione, nessuna persistenza, nessun raw `SyncPreview` / `RunSummary` / `RemotePreviewSummary` nella card Release, `supportsGuidedManualSync` resta false.
- **TASK-075** resta **TODO**.

---

## Decisioni / Note

- **TASK-075** rimane nel backlog **TODO**; nessuna interferenza.
