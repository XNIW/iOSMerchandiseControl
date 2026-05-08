# TASK-078 — Pull apply locale guidato (Release)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-078 |
| **Titolo** | Pull apply locale guidato — da preview remota a SwiftData dopo conferma |
| **File task** | `docs/TASKS/TASK-078-supabase-mutative-sync-pull-apply-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Claude / Reviewer |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 14:47 -0400 — REVIEW/FIX/CHIUSURA completata; TASK-078 DONE su override utente. |
| **Ultimo agente** | Claude / Reviewer |

## Dipendenze

- **Dipende da:** TASK-077 **DONE / Chiusura** (sheet **Rivedi** UI-only poi collegata in TASK-078); TASK-073/074/076 come contesto Release read-only e audit; infra storica TASK-039/040/041+ per `SupabasePullApplyService`, baseline, ecc.
- **Sblocca:** percorsi UX successivi solo come backlog futuro; **TASK-079 non è stato aperto** in TASK-078.

---

## Obiettivo

Collegare la **preview remota Supabase** gia’ disponibile in Release (lettura/diff tramite servizi esistenti) a un **apply locale controllato su SwiftData** (`Product`, `Supplier`, `ProductCategory`), **solo dopo conferma utente esplicita**, con summary user-facing gia’ nel modello TASK-074 e sheet **Rivedi** TASK-077.

**Fuori scope confermato:** push remoto, drain outbox, ProductPrice/history sync completa (roadmap separata), sync automatica, polling/Realtime/BGTask/worker, backend/SQL/Android, abilitazione `guidedManual` o `supportsGuidedManualSync = true`.

---

## Non incluso / anti-scope verificato

- Nessun push remoto, nessun drain outbox, nessuna write Supabase.
- Nessun `project.pbxproj`, SQL/migration Supabase, backend o Android modificato.
- Nessun ProductPrice/history sync implementato in TASK-078.
- Nessun smoke live obbligatorio; la chiusura usa build, XCTest mirati, lint localizzazioni, grep e diff check.
- Nessun TASK-079 aperto.

---

## Criteri di accettazione

- [x] Percorso Release implementato: **Controlla cloud → Rivedi → Conferma → Aggiorna questo dispositivo → Summary**.
- [x] Apply locale SwiftData solo dopo conferma utente esplicita.
- [x] Staging `SyncPreview` volatile/session-scoped, invalidato su nuovo run, cancel, errore, preview partial, apply success/failure e relaunch.
- [x] `SupabasePullApplyService` resta fonte della logica `prepareApplyPlan` / `apply(plan:)`.
- [x] `prepareApplyPlan` viene rieseguito immediatamente prima di `apply(plan:)`.
- [x] `ModelContext` usato è quello fornito dalla factory Release.
- [x] Doppio tap bloccato; UI con CTA primaria singola e copy nativa iOS.
- [x] Stale local data, no applicable changes, partial preview, conflicts e save failure mappati a copy naturale.
- [x] `applyStockQuantity` resta al default `false`.
- [x] ProductPrice/history sync, push remoto, auto-sync e backend/Android restano fuori scope.
- [x] `guidedManual` non abilitato; `supportsGuidedManualSync` resta false.

---

## Scopo operativo eseguito

Portare dalla card/opzioni Release un flusso: **Controlla cloud → Rivedi → Conferma → Aggiorna questo dispositivo → Summary**, senza esporre all’utente termini tecnici vietati dalla governance Release.

---

## Planning (Claude, storico consumato)

Il planning ha individuato il gap principale: la preview remota Release veniva ridotta a summary aggregato e non conservava il `SyncPreview` applicabile dopo **Controlla cloud**. La direzione scelta in execution è stata **Opzione A**: staging volatile nel ViewModel alimentato dall’adapter preview, senza introdurre un nuovo facade o nuove dipendenze.

Decisioni risolte:

| # | Decisione | Esito |
|---|-----------|-------|
| D78-01 | Opzione A vs B staging | **Opzione A** implementata. |
| D78-02 | Usare `.dryRun` + side-channel apply VS nuovo mode/`guidedManual` | `.dryRun` mantenuto; nessun `guidedManual` abilitato. |

Inventario finale:

| Componente | Stato finale |
|------------|--------------|
| `SupabaseManualSyncPullPreviewAdapter` | Conserva staging volatile solo su preview completa `.success`; clear esplicito disponibile. |
| `SupabaseManualSyncViewModel` | Orchestrazione UI/stato/intent utente; chiama `SupabasePullApplyService` per prepare/apply. |
| `SupabaseManualSyncReleaseFactory` | Inietta adapter staging, `SupabasePullApplyService` e `ModelContext` Release. |
| `OptionsView` Release card/sheet | Mostra **Rivedi**, conferma nativa e CTA **Aggiorna questo dispositivo**. |
| `SupabasePullApplyService` | Resta fonte della logica apply locale catalogo. |
| ProductPrice/history sync | **OUT OF SCOPE TASK-078**. |
| Push catalogo / drain outbox / auto-sync | **OUT OF SCOPE TASK-078**. |

Micro-slice completate:

1. **S78-a — Staging + gates read-only:** `SyncPreview` completo trattenuto solo in memoria dopo preview completa.
2. **S78-b — Confirm UX:** CTA finale rinominata **Aggiorna questo dispositivo**, abilitata solo se i guard permettono apply.
3. **S78-c — Apply wired:** conferma ⇒ `prepareApplyPlan` immediatamente prima di `apply(plan:)` su `ModelContext` Release.
4. **S78-d — Summary post-apply:** stato **Dati locali aggiornati** con conteggi essenziali.
5. **S78-e — Hardening test + cancellation:** coperti partial, stale, conflitti, save failure/static rollback, cancel/relaunch e label legacy.

Anti-scope checklist finale:

- [x] No `guidedManual` abilitato.
- [x] No `supportsGuidedManualSync = true` in Release.
- [x] No push remoto/outbox drain.
- [x] No ProductPrice/history sync dentro TASK-078.
- [x] No auto-sync/timer/BGTask/realtime/polling/worker.
- [x] No SQL/backend/Android modificati.
- [x] No TASK-079 aperto.

Rischi/follow-up fuori scope:

- Baseline/snapshot persistente non viene aggiornato automaticamente dopo `apply(plan:)`; la UI suggerisce un nuovo **Controlla cloud** manuale.
- Performance su dataset grande resta area da monitorare in task futuri se l’apply locale risultasse percepibilmente lungo.

## Execution (Codex)

### Avvio EXECUTION — Definition of Ready repo-grounded (storico)

Override utente ricevuto per avviare EXECUTION. In quel momento TASK-078 è passato a **ACTIVE / EXECUTION**, **NON DONE**.

Verifiche DoR obbligatorie:

1. **Produzione preview completa:** `SupabasePullPreviewService.generatePreview(context:)` produce `SupabasePullPreviewViewState.success(SyncPreview)` o `.partial(SyncPreview, ...)`; `SupabaseManualSyncPullPreviewAdapter` oggi riduce il risultato ad aggregate summary.
2. **Trattenzione in memoria:** `SyncPreview` è già il payload applicabile ridotto a summary/diff/apply payload, non l'intero dump remoto; può essere trattenuto come unico staging volatile session-scoped, senza persistenza e senza duplicare nuove strutture enormi.
3. **ModelContext Release:** `OptionsView` passa `@Environment(\.modelContext)` a `SupabaseManualSyncReleaseCard`, che lo passa a `SupabaseManualSyncReleaseFactory.makeViewModel(...)`; lo stesso context è usato dall'adapter preview.
4. **Stock:** `SupabasePullApplyOptions.applyStockQuantity` ha default `false`; TASK-078 userà il default e non prometterà aggiornamento stock.
5. **Invalidazione staging su snapshot locale cambiato:** `prepareApplyPlan` rigenera snapshot SwiftData; `apply(plan:)` richiama `validateNotStale`. Errori `.previewStale` / `.noApplicableChanges` invalidano lo staging e chiedono un nuovo controllo cloud.
6. **View/sheet CTA:** `OptionsView.SupabaseManualSyncReleaseCard` possiede `isReviewSheetPresented`; `SupabaseManualSyncReviewSheet` renderizza la sheet **Rivedi** e la CTA primaria.
7. **Post-apply baseline/snapshot:** `SupabasePullApplyService.apply(plan:)` aggiorna solo SwiftData (`Product`, `Supplier`, `ProductCategory`) e non aggiorna automaticamente baseline/snapshot persistente. Dopo successo la UI mostrerà summary locale e suggerirà un nuovo **Controlla cloud** manuale, senza auto-sync.
8. **PII/log:** nessun log Release nel percorso manual sync; gli errori apply saranno mappati a copy generico, senza barcode, nomi prodotto, UUID o payload remoto.
9. **Test/label vecchia:** prima della execution erano da aggiornare la vecchia CTA `Applica modifiche`, la chiave `options.supabase.manualSync.review.action.applyFuture` e i test statici collegati; in chiusura la label resta solo come assert negativo o storico marcato.
10. **File/test/rollback:** file previsti: `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `OptionsView.swift`, `Localizable.strings` IT/EN/ES/zh-Hans, test mirati ViewModel/RemotePreview/ReleaseUI e tracking docs. Test minimi: XCTest mirati manual sync/pull apply, localizzazioni `plutil`, `git diff --check`, build se l'ambiente lo consente. Rollback: rimuovere injection apply/staging, ripristinare adapter summary-only e CTA disabilitata.

Decisioni execution:

- **D78-01:** scelta **Opzione A** — staging volatile nel ViewModel alimentato dall'adapter preview.
- **D78-02:** si mantiene `.dryRun` come controllo cloud read-only; nessun nuovo mode pubblico e nessuna abilitazione `guidedManual`.

### S78-a…S78-i — Execution completata per review

Micro-slice completate:

- **S78-a — Staging preview minimale:** `SupabaseManualSyncPullPreviewAdapter` conserva in memoria solo `SyncPreview` completo/applicabile e invalida staging su nuovo run, cancel, errore, partial e clear esplicito.
- **S78-b — Eligibility + copy bloccanti:** `SupabaseManualSyncViewModel` espone `canApplyLocalChanges`, `applyBlockedReason`, `isApplyingLocalChanges`, `lastLocalApplySummary`; la UI riceve solo copy user-facing.
- **S78-c — CTA sheet + conferma iOS:** sheet **Rivedi** collegata alla CTA primaria **Aggiorna questo dispositivo**; conferma SwiftUI standard con copy richiesto.
- **S78-d — Apply locale SwiftData:** dopo conferma il ViewModel ricontrolla staging, prepara il piano subito prima dell'apply, chiama `SupabasePullApplyService.apply(plan:context:)`, blocca doppio tap e resetta staging.
- **S78-e/S78-h — Summary post-apply e verifica manuale:** successo mostra **Dati locali aggiornati** con conteggi essenziali; nessun refresh automatico, suggerito nuovo **Controlla cloud** manuale.
- **S78-f — Test hardening:** aggiunti/aggiornati test per preview full/partial, conflitti, warning non bloccanti, stale local data, cancel/relaunch, double tap, privacy/copy, ProductPrice untouched, rollback save path statico e label consistency.
- **S78-g — Localizzazione:** aggiornate solo chiavi necessarie IT/EN/ES/zh-Hans; vecchia label finale rimossa dalle stringhe Release.
- **S78-i — Consistency pass:** nessun copy tecnico, nessuna promessa stock/prezzi, nessun push/sync completo, nessun log PII introdotto.

File modificati:

- `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-078-supabase-mutative-sync-pull-apply-ios.md`

Check eseguiti:

- ✅ **Build compila:** `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` — PASS.
- ✅ **XCTest mirati:** `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncRemotePreviewTests`, `SupabaseManualSyncReleaseUITests`, `SupabasePullApplyServiceTests` — PASS (96 test).
- ✅ **Localizable:** `plutil -lint` su IT/EN/ES/zh-Hans — PASS.
- ✅ **Whitespace:** `git diff --check` — PASS.
- ✅ **Label consistency:** grep sorgente/test trova la vecchia label solo come assert negativo nei test; nessuna stringa Release finale mostra **Applica modifiche**.
- ⚠️ **Nessun warning nuovo introdotto:** build/test emettono warning gia' noti in file non toccati (`SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`, AppIntents metadata). Nessun warning osservato nei file TASK-078 modificati.
- ✅ **Coerenza planning / CA:** Opzione A rispettata; apply locale solo dopo conferma, staging volatile, nessun `guidedManual`, nessun push/outbox drain/auto-sync/backend/Android/TASK-079.

Rischi rimasti:

- Baseline/snapshot persistente non viene aggiornato da `apply(plan:)`; la UI suggerisce un nuovo **Controlla cloud** manuale. Eventuale baseline refresh automatico resta follow-up fuori scope.
- Simulator/manual UI end-to-end non eseguito perche' non richiesto esplicitamente dal task; copertura affidata a build, static UI tests e ViewModel tests.
- Warning Swift 6 preesistenti restano fuori perimetro.

### Handoff post-execution (storico)

- **READY FOR REVIEW:** sì.
- **Prossima fase:** REVIEW Claude.
- **Prossimo agente:** Claude / Reviewer.
- **Note:** al termine execution TASK-078 è stato lasciato **ACTIVE / REVIEW**, **NON DONE**. Non aperto TASK-079.

## Review / Fix / Chiusura

Esito review: **FIXED / DONE**.

Controlli review eseguiti:

- Codice controllato in dettaglio: `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `OptionsView.swift`, localizzazioni IT/EN/ES/zh-Hans e test mirati.
- Diff TASK-078 controllato file per file; nessuna modifica fuori perimetro rilevata.
- UX Release verificata: CTA finale **Aggiorna questo dispositivo**, sheet **Rivedi**, conferma nativa breve, nessuna UI finale con vecchia label, niente jargon tecnico visibile.
- Log/privacy verificati: nessun log nuovo con barcode, nomi prodotto, UUID sensibili o payload remoto completo.
- Anti-scope verificato: nessun push remoto, drain outbox, auto-sync, polling, BGTask, Realtime, worker, backend/SQL/Android, ProductPrice/history sync, TASK-079.

Fix applicati in review:

- `OptionsView.swift`: aggiunto spinner nativo nella CTA primaria del foglio mentre l’aggiornamento locale è in corso; cancellazione task apply su disappear/reset per evitare UI concorrenti.
- `SupabaseManualSyncViewModel.swift`: aggiunto yield prima del lavoro apply sincrono per rendere visibile lo stato di avanzamento; mantenuto `prepareApplyPlan` immediatamente prima di `apply(plan:)`.
- Test statici/ViewModel aggiornati per coprire `primaryActionIsLoading` e la UI di progresso.
- Documentazione TASK-078 riallineata: planning marcato come storico consumato, decisioni risolte, anti-scope aggiornato, formulazioni obsolete rimosse o rese storiche.

Check finali:

- ✅ **Build Release:** `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` — PASS.
- ✅ **XCTest mirati:** `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncRemotePreviewTests`, `SupabaseManualSyncReleaseUITests`, `SupabasePullApplyServiceTests` — PASS (96 test, 0 failure).
- ✅ **Localizable `plutil -lint`:** IT/EN/ES/zh-Hans — PASS.
- ✅ **`git diff --check`:** PASS.
- ✅ **Grep finali anti-label/anti-jargon:** vecchia label presente solo in assert negativo o storico marcato; nessuna UI Release finale con **Applica modifiche**; nessun copy `options.supabase.manualSync.*` con baseline/outbox/RPC/sync_events/apply plan.
- ✅ **Anti-scope statico:** nessun `TASK-079` file, nessun `applyStockQuantity: true`, nessun log nuovo, nessun backend/SQL/Android modificato.

Rischi residui:

- Baseline/snapshot persistente non viene aggiornato automaticamente dopo l’apply locale; la UI suggerisce un nuovo **Controlla cloud** manuale. Resta fuori scope TASK-078.
- Warning Swift 6 preesistenti su file non TASK-078 restano fuori perimetro se riappaiono in build/test.
- Nessun test manuale Simulator end-to-end eseguito perché non richiesto come gate obbligatorio; la copertura è build + XCTest + static checks.

Motivazione chiusura:

- Tutti i criteri TASK-078 risultano soddisfatti dopo review/fix.
- Le modifiche sono micro-fix mirati, reversibili e coerenti con UX nativa iOS.
- Nessun blocker tecnico aperto; TASK-078 chiuso **DONE / Chiusura** su override esplicito dell’utente.
