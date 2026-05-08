# TASK-077 — UX/UI Release review sheet Supabase manual sync iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-077 |
| **Titolo** | UX/UI Release per conferma sync mutativa — review sheet iOS |
| **File task** | `docs/TASKS/TASK-077-supabase-mutative-sync-release-review-sheet-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Slice** | S77-a |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 13:35 -0400 — review tecnica S77-a approvata e chiusa; progetto riportato IDLE. |
| **Ultimo agente** | Codex / Reviewer |
| **Ultimo completato** | TASK-076 DONE / Chiusura |

## Dipendenze

- **Dipende da:** TASK-076 **DONE / Chiusura** come audit/planning; TASK-072…TASK-075 **DONE / Chiusura** come base Release read-only.
- **Sblocca:** review della prima superficie UX non mutativa; solo dopo review separata potra' partire TASK-078 per pull apply reale.

## Obiettivo

Implementare una prima **UI Release non mutativa** per rivedere modifiche cloud/locali prima di una futura sync mutativa.

Questa slice prepara il flusso:

**Controlla cloud -> Rivedi modifiche -> Conferma -> Applica/Invia -> Summary**

ma **S77-a non applica, non invia e non drena nulla**.

## Perimetro execution S77-a

Consentito:

- `OptionsView.swift`
- `SupabaseManualSyncViewModel.swift`
- eventuali modelli presentation gia' esistenti legati a `SupabaseManualSyncPresentationState`
- test Swift/XCTest collegati alla UI/presentation
- `Localizable.xcstrings` / localizzazioni IT, EN, ES, zh-Hans se usate dal progetto
- helper piccoli nello stesso modulo solo se riducono logica dentro la View

Fuori perimetro:

- backend Supabase, SQL, migration, RLS/RPC
- Android
- apply/pull mutativo reale, push reale, ProductPrice sync reale
- drain outbox Release reale
- sync automatica, Timer, BGTask, Realtime, worker, polling
- reset/truncate/delete outbox
- refactor grande non necessario

## Criteri di accettazione S77-a

- [x] Card Supabase in `OptionsView` resta compatta: titolo, sottotitolo, badge, una CTA primaria coerente.
- [x] Aggiunta/cablata una sheet SwiftUI leggera per la review/conferma futura.
- [x] Sheet user-facing con sezioni:
  - Dal cloud al dispositivo
  - Dal dispositivo al cloud
  - Prezzi
  - Attenzione, solo se serve
  - CTA footer
- [x] Sheet read-only / preview-only: nessuna mutazione locale o remota.
- [x] CTA mutativa futura disabilitata e accompagnata da copy "prossimo passaggio".
- [x] Nessun apply reale, nessun push reale, nessun drain reale.
- [x] Nessuna modifica SwiftData, nessuna scrittura Supabase, nessuna modifica outbox.
- [x] `supportsGuidedManualSync` resta `false`; `guidedManual` non viene abilitato.
- [x] Copy Release senza termini vietati: outbox, drain, RPC, DTO, payload, sync_events, record_sync_event, baseline, PhaseOutcome, SyncPreview, UUID grezzi, stack trace, JSON, raw error.
- [x] Test mirati e check statici coprono ViewModel/UI presentation e localizzazioni modificate.

## Preferenze UI/UX

- Usare card compatta in `OptionsView` + sheet SwiftUI leggera.
- Non creare una nuova schermata pesante.
- Non aggiungere `NavigationStack` nuovo se non necessario.
- I dettagli stanno nella sheet; la card resta semplice.
- Sheet stile nativo Apple: titolo chiaro, sezioni brevi, SF Symbol coerenti, colori semantici SwiftUI, CTA primaria/secondaria in basso.
- Copy breve, massimo 1-2 frasi per blocco.
- In caso di scelta ambigua, preferire la soluzione piu' sicura e chiara per l'utente.

## Check richiesti

Da eseguire se disponibili nel workspace:

- Build Debug
- Build Release
- XCTest mirati per:
  - `SupabaseManualSyncViewModel`
  - UI Release Supabase manual sync
  - localizzazioni se modificate
- `git diff --check`
- controllo statico che `OptionsView` non contenga:
  - `.rpc`
  - `.from`
  - `.upsert`
  - `SupabaseClient`
  - `record_sync_event`
  - `SyncPreview` raw
  - `outbox` come copy Release visibile

## Handoff verso EXECUTION

| Voce | Valore |
| --- | --- |
| **Task / stato** | **TASK-077 ACTIVE / REVIEW** |
| **Slice** | **S77-a** |
| **Execution Swift / Codex** | Completata; pronta per review |
| **Vincolo principale** | UI read-only, nessun apply/push/drain, nessuna scrittura locale/remota |
| **Prossimo agente** | Claude / Reviewer |

## Execution

### Obiettivo compreso

S77-a doveva aggiungere una prima UI Release visibile per **rivedere** modifiche cloud/locali prima di una futura sync mutativa, senza eseguire apply, push, drain, write SwiftData o write Supabase.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-076-supabase-mutative-sync-gap-audit-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`
- `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings`

### Piano minimo applicato

1. Tenere `OptionsView` come punto di ingresso.
2. Preparare nel ViewModel uno stato presentazionale gia' pronto per la sheet.
3. Rendere in SwiftUI una sheet leggera con sezioni brevi e CTA futura disabilitata.
4. Aggiungere localizzazioni additive e test mirati.
5. Verificare build/test/static check senza toccare il perimetro mutativo.

### Modifiche fatte

- Aggiunto `SupabaseManualSyncReviewSheetState` e sezioni presentazionali nel `SupabaseManualSyncViewModel`.
- Aggiunta azione UI-only `reviewChanges`: apre la sheet ma `runMode(for:)` restituisce `nil`, quindi non avvia coordinator o mutazioni.
- Dopo preview remota completa utile, la card mostra CTA **Rivedi** invece di rilanciare subito il controllo.
- Aggiunta `SupabaseManualSyncReviewSheet` in `OptionsView` con sezioni:
  - Dal cloud al dispositivo
  - Dal dispositivo al cloud
  - Prezzi
  - Attenzione solo quando ci sono segnali di attenzione aggregati
  - Footer con **Applica modifiche** disabilitato e **Annulla**
- Aggiunte chiavi localizzate IT/EN/ES/zh-Hans.
- Aggiornati test ViewModel/UI Release/localizzazioni per la sheet, il no-jargon e il comportamento non mutativo.

### Check eseguiti

- ✅ ESEGUITO — Build Debug: `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS.
- ✅ ESEGUITO — Build Release: `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS.
- ✅ ESEGUITO — XCTest mirati ViewModel/UI/localizzazioni: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests -parallel-testing-enabled NO` PASS, **58 test**, 0 failure.
- ✅ ESEGUITO — `plutil -lint` su IT/EN/ES/zh-Hans `Localizable.strings` PASS.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — static check Release card / sheet: nessun `.rpc`, `.from`, `.upsert`, `SupabaseClient`, `record_sync_event`, `SyncPreview`, `outbox`, `drain`, `RPC`, `DTO`, `payload`, `sync_events`, `baseline`, `PhaseOutcome`, `UUID`, `JSON`, `raw error` nel blocco `SupabaseManualSyncReleaseCard` + sheet.
- ✅ ESEGUITO — static check `supportsGuidedManualSync: true` su ViewModel/OptionsView/ReleaseFactory: nessun match.
- ✅ ESEGUITO — static check full-file `OptionsView.swift`: nessun `.rpc`, `.from`, `.upsert`, `SupabaseClient`, `record_sync_event`.
- ✅ ESEGUITO — static check full-file `OptionsView.swift`: presenti match preesistenti fuori S77-a per `SyncPreview` in `SupabasePullPreviewSheet` e outbox/debug in sezione `#if DEBUG`; non modificati per anti-scope e perche' fuori dalla card Release S77-a.

### Rischi rimasti

- La verifica letterale full-file `OptionsView.swift` su `SyncPreview`/outbox resta rumorosa per codice preesistente fuori dalla card Release; S77-a copre e testa il blocco Release specifico.
- Non e' stato eseguito test manuale su Simulator della sheet; copertura S77-a e' build + XCTest + static checks.
- La CTA **Applica modifiche** e' volutamente disabilitata: il wiring reale va pianificato in TASK-078.

## Handoff post-execution

| Voce | Valore |
| --- | --- |
| **Task / stato** | **TASK-077 ACTIVE / REVIEW** |
| **Slice** | **S77-a completata** |
| **Prossimo agente** | Claude / Reviewer |
| **Esito executor** | UI-only implementata e verificata; nessuna mutazione reale abilitata |
| **Non implementato** | apply reale, push reale, drain reale, SwiftData write, Supabase write, ProductPrice sync reale, `guidedManual`, `supportsGuidedManualSync = true`, backend/SQL/Android |
| **Prossimo passo consigliato** | review TASK-077 S77-a; solo dopo, TASK-078 per pull apply reale |

## Review

### Review tecnica severa — Codex / Reviewer — 2026-05-08 13:35 -0400

#### Verdetto

**APPROVED** — S77-a e' coerente con il perimetro UI-only / preview-only. Non sono emersi bug bloccanti o fix Swift necessari.

#### Problemi trovati

- Nessun problema bloccante trovato nella slice S77-a.
- Match statici full-file su `SyncPreview`, outbox, baseline e apply restano preesistenti fuori dalla card/sheet Release: aree DEBUG o preview/apply storiche non modificate da TASK-077.
- Warning build residui confermati preesistenti/out-of-scope in AppIntents metadata, `SupabaseProductPriceApplyService.swift` e `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`; nessun warning nuovo attribuito alla sheet o al ViewModel S77-a.

#### Valutazione scope / architettura / UX

- La sheet e' solo review/preview: l'azione `reviewChanges` non produce `runMode`, non avvia il coordinator e non abilita mutazioni.
- `OptionsView` resta rendering-oriented per la superficie Release: la logica delle sezioni vive nel `SupabaseManualSyncViewModel` tramite stato presentazionale.
- La card resta compatta e la sheet espone sezioni brevi: cloud -> dispositivo, dispositivo -> cloud, prezzi, attenzione solo quando ci sono segnali aggregati.
- La CTA futura **Applica modifiche** e' disabilitata e accompagnata da copy che chiarisce che l'applicazione arrivera' in un passaggio successivo.
- Copy IT/EN/ES/zh-Hans semanticamente allineato e senza jargon Release sulle chiavi `options.supabase.manualSync.*`.

#### Check eseguiti

- ✅ ESEGUITO — Build Debug: `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS.
- ✅ ESEGUITO — Build Release: `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` PASS.
- ✅ ESEGUITO — XCTest mirati: `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, `LocalizationCoverageTests` PASS, **58 test**, 0 failure.
- ✅ ESEGUITO — `plutil -lint` su IT/EN/ES/zh-Hans `Localizable.strings` PASS.
- ✅ ESEGUITO — duplicate localization keys check su `options.supabase.manualSync.*` PASS.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — static check card/sheet Release: nessun `.rpc`, `.from`, `.upsert`, `.insert`, `.update`, `.delete`, `SupabaseClient`, `record_sync_event`, apply/push/drain service o jargon vietato nel blocco `SupabaseManualSyncReleaseCard` + sheet.
- ✅ ESEGUITO — static check diff S77-a: nessun apply/push/drain reale; match su `applyFuture` e `vm.apply(summary:)` sono rispettivamente copy CTA disabilitata e test helper/viewmodel apply di summary.
- ✅ ESEGUITO — `supportsGuidedManualSync: true` non presente in `OptionsView`, `SupabaseManualSyncViewModel` o `SupabaseManualSyncReleaseFactory`; match nei test storici di capability guidata restano fuori Release S77-a.

#### Rischi residui

- Nessun test manuale Simulator della sheet eseguito in questa review; la copertura e' build + XCTest mirati + static check.
- La CTA mutativa resta volutamente disabilitata: il wiring reale andra' pianificato separatamente in **TASK-078**.

## Fix

### Fix applicati

- Nessun fix Swift necessario.
- Aggiornato solo tracking di chiusura TASK-077 / MASTER-PLAN dopo review PASS.

## Chiusura

### Chiusura — 2026-05-08 13:35 -0400

- **TASK-077 DONE / Chiusura**.
- **TASK-076 resta DONE / Chiusura** come planning-only.
- **TASK-078 resta TODO / Planning**, non avviato.
- Progetto riportato a **IDLE**.

Conferma anti-scope finale:

- Nessun apply reale.
- Nessun push reale.
- Nessun drain reale.
- Nessun write SwiftData.
- Nessun write Supabase.
- Nessun ProductPrice sync reale.
- Nessun `guidedManual` abilitato.
- Nessun `supportsGuidedManualSync = true`.
- Nessun backend, SQL, migration o Android modificato.
