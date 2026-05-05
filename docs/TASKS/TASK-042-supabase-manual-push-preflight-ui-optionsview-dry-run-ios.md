# TASK-042 — Supabase manual push preflight UI in OptionsView, dry-run only, tombstone-compliant

## Informazioni generali
- **Task ID**: TASK-042
- **Titolo**: Supabase manual push preflight UI in OptionsView, dry-run only, tombstone-compliant
- **File task**: `docs/TASKS/TASK-042-supabase-manual-push-preflight-ui-optionsview-dry-run-ios.md`
- **Stato**: DONE
- **Fase attuale**: DONE
- **Responsabile attuale**: Utente / Chiusura
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05 *(review completa + fix piccoli PASS; DONE su override utente)*
- **Ultimo agente che ha operato**: Claude Code (review/fix/done)

## Dipendenze
- **Dipende da**: TASK-038 (DONE), TASK-039 (DONE), TASK-040 (DONE), TASK-041 (DONE)
- **Riferimento Android/Supabase (non copia 1:1)**: TASK-068 (PARTIAL), TASK-069 (DONE), TASK-070 (DONE), TASK-071 (DONE)

## Scopo
Introdurre in iOS una sezione DEBUG in `OptionsView` che permetta all'utente di eseguire il preflight/dry-run manual push locale gia' preparato da TASK-041, mostrando stato account, riepilogo candidati/blocchi e motivi di blocco, con copy esplicita che confermi l'assenza totale di scritture su Supabase.

## Out of scope vincolante
- Nessuna scrittura Supabase (`insert`/`update`/`upsert`/`delete`).
- Nessun `record_sync_event`, nessun outbox, nessun dirty flag persistente.
- Nessuna baseline persistence.
- Nessun ProductPrice push.
- Nessun realtime/background sync.
- Nessun delete remoto da tombstone.
- Nessuna modifica Android.
- Nessuna migration SQL o cambio schema Supabase live.
- Nessun refactor ampio di `OptionsView`.

## Fonti lette prima del planning
### iOS
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
- `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`
- `iOSMerchandiseControlTests/SupabasePullPreviewPaginationTests.swift`
- `iOSMerchandiseControlTests/SupabaseConfigSecurityTests.swift`

### Android
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-068-bulk-product-push-verifica-no-op-post-full-import.md`
- `docs/TASKS/TASK-069-audit-sync-residui-outbox-price-generated-history.md`
- `docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md`
- `docs/TASKS/TASK-071-backend-rpc-record-sync-event-payload-validation.md`
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/CatalogSyncViewModel.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/SyncEventModels.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/SupabaseSyncEventRemoteDataSource.kt`

### Supabase locale (read-only)
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`
- Verifica contratto `record_sync_event`: presente limite `p_changed_count > 1000` e regole payload; non da usare in TASK-042.

## Differenze Android -> iOS considerate
1. Android TASK-068 e' PARTIAL: bulk push reale lato client esiste ma validazione live completa no; non importare questa strategia in iOS TASK-042.
2. Android TASK-069/070 trattano outbox/retry e logging sync events: fuori scope iOS TASK-042.
3. Android TASK-071 mostra rischio contrattuale backend su `record_sync_event` e `changed_count`: in iOS TASK-042 non va introdotto nessun path eventi RPC.
4. iOS TASK-042 resta UI preflight/dry-run locale; nessun passo verso write remota.

## Planning
### Obiettivo
Fornire in `OptionsView` una UI DEBUG minima, chiara e localizzata che permetta preflight/dry-run manuale locale dei candidati push, evidenziando blocchi e motivi senza inviare dati al cloud.

### Analisi
- TASK-041 ha gia' introdotto modelli/servizio preflight puri (`SupabaseManualPushPreflight*`) con categorie blocco/warning/future-only.
- `OptionsView` ha gia' pattern DEBUG auth-gated e sheet/summary per preview/apply locale, quindi l'integrazione puo' restare incrementale.
- Vincolo principale: evitare qualsiasi ambiguita' UX di "push reale"; la copy deve ripetere dry-run/no-write/futuro task.
- Per dataset ampi, il preflight va orchestrato senza bloccare il main thread.

### Approccio
1. Aggiungere in DEBUG una subsection dedicata al preflight manual push in `OptionsView` (senza bottone push reale attivo).
2. Riutilizzare `SupabaseManualPushPreflightService` e modelli TASK-041; introdurre solo un leggero state holder/view model UI se necessario.
3. Stati UI previsti: `idle`, `accountNotLinked`, `running`, `completedSafe`, `completedBlocked`, `failedLocalError`.
4. Mostrare riepilogo compatto:
   - candidati prodotti/supplier/categorie;
   - bloccati account mismatch;
   - bloccati `remoteID` mancante;
   - bloccati tombstone/delete;
   - bloccati dati incompleti/barcode invalidi;
   - risultato dry-run safe/non applicabile;
   - lista motivi blocco.
5. Copy esplicita in UI:
   - "Dry-run locale: nessun dato viene inviato a Supabase."
   - "Il push reale sara' implementato in un task futuro."
6. Localizzazione completa IT/EN/ES/ZH-Hans con chiavi nuove coerenti.
7. Test puri aggiuntivi per formatting/riepilogo ViewModel/helper UI, zero rete.

### Decisione UI/UX per futura execution
La UI TASK-042 deve restare leggera e coerente con `OptionsView`, senza introdurre una schermata nuova.

Scelta UX:
- Usare una `Section` DEBUG dentro `OptionsView`, nello stesso stile delle sezioni Supabase gia' presenti.
- Non usare una nuova view navigata.
- Non usare uno sheet full-screen per la prima slice.
- Usare una summary card inline + `DisclosureGroup` per dettagli/blocchi.
- Nessun bottone "Push", "Sync", "Upload" o testo che possa sembrare una scrittura reale.
- CTA unica: "Esegui verifica locale" / "Run local check".
- CTA secondaria opzionale solo se utile: "Aggiorna verifica".
- Durante `running`, disabilitare il bottone e mostrare `ProgressView`.
- Senza account collegato, mostrare stato bloccato con CTA gia' esistente verso login/account se presente; non duplicare login UI.
- Se risultato safe: mostrare stato positivo, ma con copy "Pronto per un futuro push. Nessun dato e' stato inviato."
- Se risultato blocked: mostrare stato warning, riepilogo contatori e dettagli espandibili.
- I dettagli devono usare icone + testo, non solo colore.
- Supportare Dynamic Type: evitare layout troppo densi, preferire `VStack(alignment: .leading)` e testi brevi.

Copy obbligatoria:
- "Dry-run locale: nessun dato viene inviato a Supabase."
- "Il push reale sara' implementato in un task futuro."
- "Questa verifica non modifica dati locali ne' remoti."

### State machine UI proposta
Stati minimi:
- `idle`: mostra descrizione e bottone "Esegui verifica locale".
- `accountNotLinked`: mostra messaggio bloccante; nessun preflight.
- `running`: mostra `ProgressView`, bottone disabilitato, copy "Analisi locale in corso...".
- `completedSafe`: mostra card positiva con candidati pushabili e zero blocchi critici.
- `completedBlocked`: mostra card warning con blocchi e `DisclosureGroup` dei motivi.
- `failedLocalError`: mostra errore locale recuperabile; nessuna rete, nessuna scrittura.

Regola UX:
- Nessuna `confirmationDialog` prima del dry-run, perche' non scrive nulla.
- Eventuale `alert` solo per errore locale non rappresentabile inline.
- Risultato precedente puo' restare visibile finche' l'utente non rilancia la verifica.

### Concurrency e performance
Vincoli:
- Non passare `ModelContext` dentro `Task.detached`.
- Rispettare il pattern gia' usato dai servizi SwiftData esistenti.
- Estrarre snapshot locale in modo sicuro secondo `SwiftDataInventorySnapshotService`.
- Dopo lo snapshot, eventuale calcolo puro puo' lavorare solo su modelli `Sendable` / value type.
- Aggiornare stato UI su `@MainActor`.
- Evitare blocco main thread su dataset grandi.
- Disabilitare rilanci multipli mentre `running`.
- Se `OptionsView` viene chiusa durante `running`, evitare update incoerenti o memory leak; documentare eventuale cancellazione task se si introduce uno state holder.

### Privacy e sicurezza visuale
- Non mostrare token, JWT, URL complete o dati sensibili Supabase.
- Mostrare account/email solo nel modo gia' usato da `OptionsView`.
- Nei dettagli blocchi, evitare dump completo prodotto; usare barcode/nome solo se gia' normale nel resto dell'app.
- Preferire conteggi e motivi aggregati.
- Nessun log con payload completo.

### Chiavi localizzazione previste
Proposta chiavi:
- `supabase_push_preflight_title`
- `supabase_push_preflight_subtitle`
- `supabase_push_preflight_run_button`
- `supabase_push_preflight_refresh_button`
- `supabase_push_preflight_dry_run_note`
- `supabase_push_preflight_future_push_note`
- `supabase_push_preflight_no_local_changes_note`
- `supabase_push_preflight_account_required`
- `supabase_push_preflight_running`
- `supabase_push_preflight_safe_title`
- `supabase_push_preflight_blocked_title`
- `supabase_push_preflight_failed_title`
- `supabase_push_preflight_products_candidates`
- `supabase_push_preflight_suppliers_candidates`
- `supabase_push_preflight_categories_candidates`
- `supabase_push_preflight_blocked_account_mismatch`
- `supabase_push_preflight_blocked_missing_remote_id`
- `supabase_push_preflight_blocked_tombstone`
- `supabase_push_preflight_blocked_invalid_barcode`
- `supabase_push_preflight_blocked_incomplete_data`
- `supabase_push_preflight_details_title`

Nota: in execution futura queste chiavi devono essere compilate in IT/EN/ES/ZH-Hans.

### Matrice test futura
- **T-1 Account assente**: stato `accountNotLinked`, bottone preflight disabilitato o bloccato, nessun servizio push chiamato.
- **T-2 Stato running**: bottone disabilitato, `ProgressView` visibile, nessun doppio lancio.
- **T-3 Risultato safe**: conteggi candidati mostrati, copy dry-run/no-write presente.
- **T-4 Risultato blocked**: blocchi aggregati mostrati, dettagli espandibili.
- **T-5 Tombstone/delete**: record tombstone conteggiato come bloccato, nessuna preparazione delete remoto.
- **T-6 Missing remoteID**: record senza remote bridge mostrato come bloccato.
- **T-7 Barcode invalido/incompleto**: motivo blocco specifico.
- **T-8 ProductPrice escluso**: nessun conteggio o path ProductPrice push.
- **T-9 Localizzazioni**: nuove chiavi presenti in IT/EN/ES/ZH-Hans.
- **T-10 Anti-scope grep**: nessun `record_sync_event`, nessun outbox, nessun ProductPrice push, nessuna migration SQL, nessuna modifica Android, nessuna chiamata Supabase `insert`/`update`/`upsert`/`delete` per push.

### File coinvolti (futura execution)
- `iOSMerchandiseControl/OptionsView.swift`
- eventuale `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift` (o helper equivalente)
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift` (solo se strettamente necessario)
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift` (solo se strettamente necessario)
- `iOSMerchandiseControl/Localizable.strings` (IT/EN/ES/ZH-Hans)
- `iOSMerchandiseControlTests/*` (test puri UI summary/formatting)

### Rischi
- **Percezione utente:** la UI potrebbe sembrare un push reale -> mitigare con copy ripetuta dry-run/no-write.
- **Scope creep da Android:** evitare introduzione bulk push/outbox/sync events.
- **Rischio backend RPC:** nessun utilizzo `record_sync_event` in TASK-042.
- **Performance UI:** eseguire preflight fuori main thread e aggiornare stato su main actor.
- **Regressione auth-gating TASK-038:** mantenere gating sessione invariato.

### Criteri di accettazione
- **CA-1** `OptionsView` mostra sezione DEBUG preflight solo nel pattern debug gia' usato.
- **CA-2** UI richiede sessione Supabase valida; senza account collegato blocca preflight.
- **CA-3** Preflight usa solo SwiftData locale + servizi puri/no-network TASK-041.
- **CA-4** Nessuna scrittura Supabase o rete di push introdotta.
- **CA-5** Riepilogo distingue safe candidates, blocked items e motivi blocco.
- **CA-6** Normalizzazione barcode/account baseline coerente con microfix TASK-041.
- **CA-7** Tombstone/delete non inviati ne' preparati per push reale.
- **CA-8** ProductPrice escluso dal push.
- **CA-9** Nessun outbox/dirty/sync_events/baseline persistente.
- **CA-10** Localizzazioni IT/EN/ES/ZH-Hans complete.
- **CA-11** XCTest TASK-041 restano verdi.
- **CA-12** Nuovi test puri per formatting/riepilogo UI o ViewModel senza rete.
- **CA-13** Build Debug PASS.
- **CA-14** Build Release PASS.
- **CA-15** XCTest completo PASS.
- **CA-16** `git diff --check` PASS.
- **CA-17** Anti-scope PASS (`record_sync_event`, outbox, ProductPrice push, migration SQL, Android changes assenti).
- **CA-18** UI coerente con `OptionsView`: sezione inline, summary card, dettagli espandibili, nessuna schermata nuova.
- **CA-19** Copy dry-run/no-write/future-push visibile in ogni stato completed.
- **CA-20** Dynamic Type/accessibility: nessuna informazione comunicata solo dal colore.
- **CA-21** SwiftData concurrency safe: nessun `ModelContext` usato fuori dal contesto/actor corretto.
- **CA-22** Nessun bottone o label che prometta push/sync reale.
- **CA-23** Stato precedente gestito in modo prevedibile quando si rilancia la verifica.
- **CA-24** Errori locali mostrati inline e recuperabili.

### Handoff post-planning
- **Prossima fase**: EXECUTION (solo con user override esplicito)
- **Prossimo agente**: Cursor/Codex executor
- **Prossima azione consigliata**: execution in una sola slice piccola e controllata:
  1. state holder/helper UI;
  2. sezione `OptionsView`;
  3. localizzazioni;
  4. test puri;
  5. anti-scope grep.
- Non separare in piu' slice salvo problemi reali emersi nel codice.
- TASK-043 futuro potra' coprire "manual push reale controllato", ma TASK-042 non deve preparare nessuna scrittura remota.

---

## Execution (Codex)
### File letti (execution)
- `docs/TASKS/TASK-042-supabase-manual-push-preflight-ui-optionsview-dry-run-ios.md`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`

### Categorie preflight realmente supportate dal modello TASK-041 (verificate)
- `dryRunCreateCandidate`
- `dryRunUpdateCandidate`
- `noOpAlreadySynced`
- `blockedNoRemoteID`
- `blockedAccountMismatch`
- `blockedPartialPull`
- `blockedMissingBaseline`
- `blockedRemoteConflict`
- `blockedTombstoneConflict`
- `blockedMissingSupplierCategoryRemoteID`
- `warningLocalOnlySupplierCategory`
- `warningStaleRemote`
- `futurePricePushCandidate`

Nota execution: il modello corrente **non** espone categorie dedicate `invalid barcode` / `incomplete data`; la UI TASK-042 usa solo categorie reali del modello (nessuna UI fittizia).

### File modificati
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift` *(nuovo)*
- `iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests.swift` *(nuovo)*
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Cosa e' stato implementato
1. Sezione DEBUG inline in `OptionsView` per preflight/dry-run locale (nessuna nuova schermata).
2. CTA unica: `Esegui verifica locale`; nessun bottone `Push`/`Upload`/`Sync` operativo.
3. State holder leggero `SupabasePushPreflightViewModel` con stati:
   - `idle`
   - `accountNotLinked`
   - `running`
   - `completedSafe`
   - `completedNoWork`
   - `completedBlocked`
   - `failedLocalError`
4. Summary card inline + `DisclosureGroup` dettagli con aggregazione per categoria, icone/testo, conteggi e limite esempi con `+ altri X`.
5. Copy dry-run/no-write/future-task sempre visibile nel footer sezione.
6. Concurrency rispettata:
   - snapshot locale tramite `SwiftDataInventorySnapshotService` su `@MainActor`
   - nessun passaggio `ModelContext` in `Task.detached`
   - calcolo puro `makePreview` su input `Sendable`
   - cancellazione task in `onDisappear`/`deinit`.
7. Localizzazioni aggiunte in IT/EN/ES/ZH-Hans.
8. Test puri aggiunti per state mapping/summary/category grouping/future-only ProductPrice.

### Fuori scope confermato (non implementato)
- Nessuna scrittura Supabase (`insert`/`update`/`upsert`/`delete`).
- Nessun `record_sync_event`.
- Nessun outbox.
- Nessuna persistenza dirty flag.
- Nessuna baseline persistence nuova.
- Nessun ProductPrice push reale (solo future-only categoria modello).
- Nessuna modifica Android.
- Nessuna migration SQL / schema Supabase.

### Risultati test/check
- ✅ Build Debug PASS (`xcodebuild ... -configuration Debug build`, iPhone 16e iOS 26.2 simulator)
- ✅ Build Release PASS (`xcodebuild ... -configuration Release build`, iPhone 16e iOS 26.2 simulator)
- ✅ XCTest PASS (`xcodebuild ... test`, suite completa)
- ✅ `git diff --check` PASS
- ✅ Anti-scope PASS:
  - `record_sync_event` assente nel codice iOS modificato
  - outbox assente nel codice iOS modificato
  - dirty persistence assente
  - ProductPrice push assente (solo future-only dry-run category)
  - migration SQL assente
  - Android changes assenti
  - nessuna chiamata Supabase `insert`/`update`/`upsert`/`delete` introdotta per push
  - nessun bottone/azione UI `Push`/`Upload`/`Sync` introdotto nella nuova sezione

### Rischi residui
- Baseline preflight in questa slice resta locale/in-memory (nessuna persistence nuova): su dataset con metadata remota incompleta lo stato puo' risultare conservativo (`blocked`).
- Le categorie `invalid barcode`/`incomplete data` non esistono come classi dedicate nel modello TASK-041; eventuale dettaglio dedicato richiede estensione modello in task successivo.

### Handoff post-execution
- **Prossima fase**: REVIEW
- **Prossimo agente**: Claude / Reviewer
- **Prossima azione consigliata**: review contro CA-1...CA-24 con focus su:
  1. conformita' anti-scope/no-write
  2. correttezza state machine UI
  3. copertura test nuova + regressione TASK-041
  4. copy/localizzazione completa IT/EN/ES/ZH-Hans

## Fix (Codex)
*(Non avviata come fase separata: l'utente ha richiesto review completa con fix piccoli diretti e chiusura DONE se tutto passa. I fix applicati sono documentati nella sezione Review sotto.)*

## Review (Claude)
### File riletti
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-042-supabase-manual-push-preflight-ui-optionsview-dry-run-ios.md`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- Diff completo rispetto a `origin/main` (`19c17c5`, Task 41) incluse modifiche tracked e file untracked TASK-042.

### Controlli fatti
- CA-1...CA-24 ricontrollati: PASS dopo i fix sotto.
- GitHub/latest: `git fetch --all --prune`; `main` locale allineato a `origin/main` (`19c17c5`).
- UI nuova sotto `#if DEBUG` in `OptionsView`; nessuna sezione TASK-042 visibile in Release.
- CTA unica verificata: `Esegui verifica locale` / `Run local check`; nessuna azione `Push` / `Upload` / `Sync` nella nuova sezione.
- Categorie UI verificate solo contro il modello TASK-041: `dryRunCreateCandidate`, `dryRunUpdateCandidate`, `noOpAlreadySynced`, `blockedNoRemoteID`, `blockedAccountMismatch`, `blockedPartialPull`, `blockedMissingBaseline`, `blockedRemoteConflict`, `blockedTombstoneConflict`, `blockedMissingSupplierCategoryRemoteID`, `warningLocalOnlySupplierCategory`, `warningStaleRemote`, `futurePricePushCandidate`.
- Nessuna categoria UI fittizia per invalid barcode / incomplete data.
- State mapping verificato: `completedNoWork` = zero candidati reali + zero blocker; `completedSafe` solo con candidati reali e zero blocker; `completedBlocked` solo con blocker reali.
- ProductPrice resta future-only e non crea path di push.
- SwiftData concurrency verificata: nessun `ModelContext` in `Task.detached`; fetch SwiftData su `@MainActor`; calcolo puro su input `Sendable`; update UI su MainActor; task cancellato in `onDisappear`/`deinit`.
- Privacy/log verificata: nessun token/JWT/URL completo, nessun payload completo, dettagli limitati a esempi con cap e `+ altri X`.
- Localizzazioni IT/EN/ES/ZH-Hans verificate: chiavi nuove presenti e `plutil -lint` PASS.
- Android/Supabase schema/migration verificati: nessuna modifica.

### Fix applicati in review
- `SupabasePushPreflightViewModel.makeCompletedState`: warning/no-op/future-only non fanno piu' apparire lo stato `completedSafe`; senza candidati reali e senza blocker ora resta `completedNoWork`.
- `OptionsView`: account non collegato/non allineato mostrato subito nella sezione DEBUG, con risultati precedenti nascosti se l'account non e' piu' pronto.
- `SupabasePushPreflightViewModel`: evitata cattura di `self` nel `Task.detached`; il calcolo detached usa solo il servizio `Sendable` e input value-type.
- `SwiftDataInventorySnapshotService`: aggiunto snapshot/fetch mirato `makeManualPushPreflightProductStates()` per evitare il vecchio doppio lavoro e il fetch completo di `ProductPrice` non necessario al catalog preflight TASK-042.
- `SupabasePushPreflightViewModelTests`: aggiunti test per no-work con warning/no-op, future-only ProductPrice come no-work, limite esempi con `+ altri X`.
- Localizzazione UX: corretto `+ %d more` in ES/ZH-Hans.

### Risultati build/test/grep
- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' CODE_SIGNING_ALLOWED=NO build` → PASS.
- ✅ ESEGUITO — Build Release: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' CODE_SIGNING_ALLOWED=NO build` → PASS.
- ✅ ESEGUITO — XCTest completo: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' CODE_SIGNING_ALLOWED=NO` → PASS (`Test-iOSMerchandiseControl-2026.05.05_14-36-08--0400.xcresult`).
- ✅ ESEGUITO — `git diff --check` → PASS.
- ✅ ESEGUITO — `plutil -lint` su `Localizable.strings` IT/EN/ES/ZH-Hans → PASS.
- ✅ ESEGUITO — confronto chiavi `options.supabase.pushpreflight.*` tra EN/IT/ES/ZH-Hans → PASS.
- ✅ ESEGUITO — anti-scope grep mirato → PASS: nessun `record_sync_event`, `sync_events`, outbox, dirty, `ProductPrice push`, `.insert`, `.update`, `.upsert`, `.delete`, `rpc(` nei path preflight TASK-042.
- ✅ ESEGUITO — anti-scope modifiche Android/SQL/migration → PASS, nessun file Android o SQL modificato.
- ✅ ESEGUITO — anti-scope CTA/label nuova sezione → PASS, nessun `Push`/`Upload`/`Sync` nelle chiavi `run/header/running` TASK-042.

### Motivazione DONE
Review completa PASS con fix piccoli e mirati. Tutti i CA-1...CA-24 risultano soddisfatti, i test e le build richieste passano, e i grep anti-scope confermano che TASK-042 resta UI DEBUG dry-run/no-write, senza push reale, senza outbox/dirty/sync event, senza baseline persistence, senza ProductPrice push, senza Android e senza migration SQL. Chiusura a DONE applicata su override esplicito dell'utente.
