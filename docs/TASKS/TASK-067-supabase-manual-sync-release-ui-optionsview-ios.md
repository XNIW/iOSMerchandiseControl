# TASK-067 — UI Release “Sincronizzazione cloud” in OptionsView iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-067 |
| **Titolo** | UI Release “Sincronizzazione cloud” in OptionsView iOS |
| **File task** | `docs/TASKS/TASK-067-supabase-manual-sync-release-ui-optionsview-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 21:38 -04 — Review tecnica severa completata con **APPROVED_FIXED_DIRECTLY**; fix piccoli applicati a copy/accessibilità/test statici; build/test/check finali PASS; TASK-067 chiuso in **DONE / Chiusura** su override esplicito utente. |
| **Ultimo agente** | Codex / Reviewer+Fixer |

## Dipendenze

- **Dipende da**:
  - **TASK-066 DONE / Chiusura** — `SupabaseManualSyncViewModel` non-DEBUG + DI `SupabaseManualSyncCoordinating`.
  - **TASK-065 DONE / Chiusura** — `SupabaseManualSyncCoordinator` dry-run/mock.
  - **TASK-064/063/062/061/060** già chiusi o planning base precedente: non riaperti.
- Android/Supabase: solo riferimento funzionale/documentale. Nessun Kotlin, nessuna modifica backend.

## Scopo

Implementare in `OptionsView` una UI Release SwiftUI nativa per “Sincronizzazione cloud”, usando `SupabaseManualSyncViewModel` e mantenendo separata la card tecnica DEBUG già esistente.

## Anti-scope rigido

- No sync automatica, Timer, BGTask, Realtime, worker, polling.
- No chiamate Supabase live nuove da `OptionsView`.
- No uso diretto di `SupabaseClient` da `OptionsView` o dal ViewModel Release.
- No SQL, migration, `db push`, RPC/RLS/trigger/schema.
- No cleanup/delete/truncate/reset outbox.
- No full sync Product/ProductPrice.
- No modifica Android o backend.
- No nuova dashboard tecnica, lista `sync_events`, viewer JSON/log/payload.
- No porting/copertura UI DEBUG come UI Release.
- No creazione TASK-068.

## Criteri di accettazione

- [x] Esiste una UI Release in `OptionsView` per “Sincronizzazione cloud”.
- [x] Usa `SupabaseManualSyncViewModel` di TASK-066.
- [x] È nativa SwiftUI, leggibile e user-facing.
- [x] Non espone termini tecnici vietati.
- [x] Non introduce sync automatica.
- [x] Non usa `SupabaseClient` direttamente nella View.
- [x] Non modifica backend/Supabase/Android.
- [x] DEBUG UI tecnica resta separata e solo DEBUG.
- [x] Localizzazioni IT / EN / ES / ZH-Hans complete.
- [x] Test/check documentati.
- [x] File task e MASTER-PLAN aggiornati.

## Planning (Claude)

### Handoff verso Execution

User override controllato 2026-05-07: creare TASK-067 e implementare UI Release “Sincronizzazione cloud” in `OptionsView`, con `SupabaseManualSyncViewModel` non-DEBUG, copy localizzato e anti-scope severo. Operare su iOS come sorgente principale; Android/Supabase solo riferimento funzionale.

## Execution (Codex)

### Obiettivo compreso

Implementare una superficie Release compatta in `OptionsView` per il controllo guidato della sincronizzazione cloud, senza trasformare la UI DEBUG in UI pubblica e senza introdurre automazioni o chiamate live nuove.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-066-supabase-manual-sync-viewmodel-states-ios.md`
- `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md`
- `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/*/Localizable.strings`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests.swift`

### Piano minimo

1. Creare tracking TASK-067 e riallineare Master Plan.
2. Aggiungere una factory DI minimale per costruire il ViewModel Release con coordinator esistente e dipendenze dry-run production-safe.
3. Inserire una sezione Release non-DEBUG in `OptionsView`.
4. Localizzare copy IT / EN / ES / ZH-Hans.
5. Aggiungere test statici/localizzazione anti-jargon e anti-scope.
6. Eseguire build/test/check richiesti e handoff a Review.

### Modifiche fatte

- Aggiunta sezione Release “Sincronizzazione cloud” in `OptionsView`, separata dalle sezioni tecniche `#if DEBUG`.
- Aggiunta `SupabaseManualSyncReleaseCard` SwiftUI nativa con stato sintetico, CTA primaria, progress/disabled state e mapping user-facing degli stati `SupabaseManualSyncViewModel`.
- La card mostra subito lo stato “Serve accedere” quando non esiste una sessione attiva, senza attendere un tap sul controllo.
- Aggiunta `SupabaseManualSyncReleaseFactory` per costruire il ViewModel Release con `SupabaseManualSyncCoordinator` esistente e dipendenze dry-run/mock production-safe.
- Localizzate le nuove stringhe in IT / EN / ES / ZH-Hans sotto `options.supabase.manualSync.*`.
- Aggiunti XCTest statici/localizzazione per copertura TASK-067, no-jargon Release, assenza `SupabaseClient`/`.rpc` in `OptionsView` e anti-scope sui sorgenti Release.

### Cosa cambia per l'utente

- In `OptionsView` compare una card Release chiara per controllare la “Sincronizzazione cloud”.
- L'utente vede messaggi comprensibili per stato aggiornato, parziale, accesso richiesto, riallineamento dati, connessione, annullamento e problema tecnico-soft.
- L'azione primaria resta manual-first: accesso se necessario, altrimenti controllo guidato della sincronizzazione.

### Cosa NON cambia funzionalmente

- Nessuna sincronizzazione automatica, background, polling o Realtime.
- Nessuna chiamata Supabase live nuova da `OptionsView`.
- Nessuna modifica backend/Supabase/Android.
- La card DEBUG outbox/drain resta tecnica, separata e confinata a `#if DEBUG`.
- Il percorso Release usa ancora la slice dry-run/mock già prevista da TASK-065/TASK-066; non introduce full sync Product/ProductPrice.

### Check eseguiti

- ✅ ESEGUITO — Build Debug Simulator iPhone 16e OS 26.2: `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` PASS.
- ✅ ESEGUITO — Build Release Simulator iPhone 16e OS 26.2: `xcodebuild -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` PASS; conferma compile Release senza dipendere dalla card tecnica DEBUG.
- ✅ ESEGUITO — XCTest mirati TASK-067 + regressioni richieste con `-parallel-testing-enabled NO`: `SupabaseManualSyncReleaseUITests`, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncCoordinatorTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` PASS (186 test, 0 failure).
- ✅ ESEGUITO — `plutil -lint` su tutti i `Localizable.strings` PASS.
- ✅ ESEGUITO — scan duplicati chiavi localizzazione PASS per IT / EN / ES / ZH-Hans.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — grep anti-scope su sorgenti Release PASS: assenti `BGTask`, `Timer`, `Realtime`, `worker`, `.channel`, `SupabaseClient`, `.rpc`, `TASK-068`.
- ✅ ESEGUITO — grep copy Release PASS: assenti `outbox`, `drain`, `sync_events`, `RPC`, `payload`, `retryable` nelle stringhe `options.supabase.manualSync.*`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: i warning build residui sono preesistenti e fuori dai file TASK-067 (`SyncEventOutboxDrainService.swift`, `SupabaseProductPriceApplyService.swift`, metadata AppIntents Xcode).
- ✅ ESEGUITO — Modifiche coerenti con planning/user override e criteri di accettazione verificati via build, test statici/localizzazione e grep anti-scope.

### Rischi rimasti

- La UI Release usa la verifica dry-run/mock production-safe disponibile oggi; un riallineamento cloud reale resta fuori scope e dovrà essere pianificato in task futuro.
- Non è stato aggiunto snapshot test visuale perché il progetto non mostra un pattern snapshot SwiftUI leggero esistente e il task richiedeva di non introdurre framework nuovi.
- I warning Swift 6/AppIntents residui restano follow-up preesistenti, non introdotti da TASK-067.

### Anti-scope confermati

- Confermati: no sync automatica, no Timer, no BGTask/BackgroundTasks, no Realtime, no worker, no polling.
- Confermati: no `SupabaseClient` diretto in `OptionsView`, no `.rpc` in `OptionsView`/ViewModel/Release factory, no nuove chiamate Supabase live.
- Confermati: no SQL, migration, `db push`, RPC/RLS/trigger/schema, cleanup/delete/truncate/reset outbox.
- Confermati: no full sync Product/ProductPrice, no Android/backend, no dashboard tecnica, no lista eventi `sync_events`, no JSON/log/payload viewer, no TASK-068.

## Handoff post-execution → Review (Claude)

Execution TASK-067 completata e pronta per REVIEW.

- File modificati/aggiunti:
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
  - `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
  - `docs/TASKS/TASK-067-supabase-manual-sync-release-ui-optionsview-ios.md`
  - `docs/MASTER-PLAN.md`
- Review focus suggerito: controllare copy UX Release, separazione `#if DEBUG`, adeguatezza della factory dry-run/mock e assenza di business logic impropria nella View.
- Stato consegna: **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**. Non DONE.

## Review (Claude)

### 2026-05-07 21:38 -04 — Review tecnica severa / APPROVED_FIXED_DIRECTLY

**Verdetto review:** **APPROVED_FIXED_DIRECTLY**.

**Override esplicito utente:** richiesta autorizzava review tecnica severa in fase REVIEW, fix piccoli/medi diretti e chiusura in **DONE / Chiusura**. Sono emersi solo problemi piccoli, corretti senza cambiare architettura né perimetro.

**Esito code review:**

- Architettura coerente: `OptionsView` non contiene chiamate Supabase dirette e delega run/stati a `SupabaseManualSyncViewModel`; la factory Release costruisce il coordinator dry-run/mock TASK-065 con dipendenze locali minime.
- `SupabaseManualSyncReleaseFactory` resta piccola e non introduce `SupabaseClient`, `.rpc`, `.from`, `.upsert` o `.channel`.
- La UI Release è disponibile fuori `#if DEBUG`; la card tecnica outbox/drain resta separata sotto `#if DEBUG`.
- Uso `@StateObject` stabile nella card Release; `@ObservedObject` per auth esterna; CTA disabilitata durante run/transizioni auth.
- Nessuna automazione, background, polling, Timer/BGTask/Realtime/worker, SQL/migration/schema/RPC/RLS, cleanup outbox, full sync Product/ProductPrice, Android/backend o TASK-068.

**Problemi piccoli trovati:**

- La stringa Release per stato tecnico usava “controllo tecnico”, troppo da addetti ai lavori per una UI pubblica.
- La label accessibilità della CTA era statica e poteva annunciare “controlla” anche quando l’azione visibile era “Accedi”.
- I test statici TASK-067 non coprivano ancora `.from` / `.upsert`, `UUID`, `JSON` e `record_sync_event`.
- Mancava una verifica statica esplicita che la card outbox/drain DEBUG restasse separata dalla card Release.

**Check finali review/fix:**

| Check | Stato | Esito |
|------|-------|-------|
| Build Debug iPhone 16e OS 26.2 | ✅ ESEGUITO | `xcodebuild ... -configuration Debug ... build` → **BUILD SUCCEEDED**. Warning AppIntents metadata già noto/preesistente. |
| Build Release iPhone 16e OS 26.2 | ✅ ESEGUITO | `xcodebuild ... -configuration Release ... build` → **BUILD SUCCEEDED**. Warning Swift 6 preesistenti in `SupabaseProductPriceApplyService.swift` e `SyncEventOutboxDrainService.swift`, fuori TASK-067. |
| XCTest mirati + regressioni richieste | ✅ ESEGUITO | `SupabaseManualSyncReleaseUITests`, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncCoordinatorTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` con `-parallel-testing-enabled NO` → **187 test PASS**, 0 failure. |
| `plutil -lint` Localizable | ✅ ESEGUITO | IT / EN / ES / ZH-Hans → PASS. |
| Duplicati chiavi localizzazione | ✅ ESEGUITO | IT / EN / ES / ZH-Hans → PASS. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| Grep anti-scope Release | ✅ ESEGUITO | Sorgenti Release (`SupabaseManualSyncReleaseCard`, factory, ViewModel) senza `BGTask`, `Timer`, `Realtime`, `worker`, `.channel`, `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `TASK-068`. |
| Grep copy Release | ✅ ESEGUITO | Stringhe `options.supabase.manualSync.*` senza `outbox`, `drain`, `sync_events`, `RPC`, `payload`, `retryable`, `UUID`, `JSON`, `record_sync_event`. |
| Criteri di accettazione | ✅ ESEGUITO | Tutti i CA TASK-067 verificati dopo fix. |

## Fix (Codex)

### 2026-05-07 21:38 -04 — Fix piccoli diretti in review

- `iOSMerchandiseControl/OptionsView.swift`
  - CTA Release con `accessibilityLabel` dinamica uguale all’azione visibile, così “Accedi” non viene annunciato come “Controlla”.
- `iOSMerchandiseControl/*/Localizable.strings`
  - copy stato tecnico Release reso meno developer-facing in IT / EN / ES / ZH-Hans.
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
  - test no-jargon estesi a `UUID`, `JSON`, `record_sync_event`;
  - test anti-scope esteso a `.from` / `.upsert`;
  - test statico aggiunto per separazione card Release vs card DEBUG outbox/drain.
- Nessuna modifica a coordinator TASK-065, ViewModel TASK-066, backend/Supabase/SQL o Android.

## Chiusura

TASK-067 **DONE / Chiusura**.

- **Verdict:** **APPROVED_FIXED_DIRECTLY**.
- **Build/test/check:** PASS in chiusura.
- **Anti-scope confermati:** no sync automatica, no Timer/BGTask/BackgroundTasks, no Realtime, no worker, no polling, no Supabase live nuove da `OptionsView`, no `SupabaseClient`/`.rpc`/`.from`/`.upsert`/`.channel` nei sorgenti Release, no SQL/migration/`db push`/RPC/RLS/trigger/schema, no cleanup/delete/truncate/reset outbox, no full sync Product/ProductPrice, no Android/backend, no dashboard/lista eventi/viewer JSON/payload, no TASK-068.
- **Rischi residui:** la UI Release resta collegata alla verifica dry-run/mock production-safe disponibile oggi; il collegamento progressivo a servizi live reali o il riallineamento cloud reale va pianificato in task separato. Warning Swift 6/AppIntents residui sono preesistenti e fuori TASK-067.
- **Prossimo consigliato:** task separato per collegare gradualmente la run guidata a servizi live reali, oppure planning di riallineamento cloud reale se necessario. **TASK-068 non creato** in TASK-067.
