# TASK-135 — TASK-132D Immediate Drift Sync Unblocker

## Stato
- Task ID: TASK-135
- Workstream alias: TASK-132D
- Parent: TASK-132 DONE
- Stato task: ACTIVE
- Fase attuale: REVIEW
- Responsabile attuale: Claude / Reviewer
- Ultimo aggiornamento: 2026-06-17 20:45 -0400
- Ultimo agente: Codex / UX polish verifier-fixer

## User Override
TASK-132 e' gia' DONE nel tracking storico. Questo hotfix e' stato eseguito su istruzione esplicita utente come workstream post-DONE, senza riscrivere la storia di TASK-132 e senza riusare TASK-134 come task canonico.

## Scopo
Sbloccare la sync automatica quando account/rete sono validi e ci sono baseline assente/stale, drift/parity, remote events o delta locali trusted. "Blocked" non deve significare waiting/no-op: deve restare solo per auth/rete/permessi/account o conflitti reali che richiedono scelta utente.

## Criteri di accettazione
- Baseline assente con account valido non torna noWork: avvia bootstrap/recovery automatico.
- Bootstrap/fullRecovery iOS passano dal runtime automatico e usano snapshot recovery provider.
- Pending locale trusted iOS usa sequenza push delta + drain finale.
- Remote event/drift iOS con pending usa sequenza pull-first + push delta + drain finale.
- Android auth/foreground/network possono attivare pull-only reconcile guardato anche se il catalogo locale non e' vuoto.
- Android push automatico resta limitato a delta locali trusted e schedula un drain finale.
- UI iOS/Android non lascia "noWork"/"Waiting" mascherare baseline/drift o outcome automatici riusciti.
- Nessun service_role, nessun bypass RLS, nessun push-all.

## Execution
Codex ha applicato il fix minimo in:
- iOS decision/runtime/orchestrator/background/options:
  - `SyncDecisionEngine.swift`
  - `SyncDecisionInputProvider.swift`
  - `AutomaticSyncEngine.swift`
  - `SyncOrchestrator.swift`
  - `SyncBackgroundTaskScheduler.swift`
  - `OptionsView.swift`
  - localizzazioni Options EN/IT/ES/ZH
- iOS tests:
  - `SyncDecisionEngineTests.swift`
  - `Task118AutomaticDomainTests.swift`
  - `Task119AutomaticArchitectureTests.swift`
- Android autosync/UI:
  - `CatalogAutoSyncCoordinator.kt`
  - `CatalogSyncViewModel.kt`
- Android clean reopen/ProductPrice backfill:
  - `ProductPriceDao.kt`
  - `PriceBackfillWorker.kt`
- Android tests:
  - `CatalogAutoSyncCoordinatorTest.kt`
  - `CatalogSyncViewModelTest.kt`
  - `DefaultInventoryRepositoryTest.kt`
- Agent tooling:
  - `tools/agent/lib/supabase.sh`
  - `tools/agent/lib/sync.sh`

Override utente 2026-06-17: completata anche la prova live cross-platform su simulator/emulator senza dichiarare DONE. Durante il gate clean reopen Android e' emerso un falso pending ProductPrice: due righe `BACKFILL_CURR` generate dal backfill legacy per un prodotto cloud-linked arrivato da iOS non avevano `product_price_remote_refs`, producendo `Waiting to sync` nonostante catalog parity. Fix minimo: il backfill legacy ora salta i prodotti gia' cloud-linked e rimuove solo righe `BACKFILL_CURR` cloud-linked prive di remote bridge; il tooling counts Android include i ProductPrice local-only nel pending aggregate.

Micro-fix UX finale richiesto dall'utente: iOS Options, card `Stato database locale`, rinomina la precedente label pull-specifica in label generica di sync: IT `Ultima sincronizzazione`, EN `Last sync`, ES `Última sincronización`, zh-Hans `上次同步`. Nessuna logica runtime modificata.

Polish UX pubblico finale richiesto dall'utente, senza modifiche runtime sync:
- iOS Options: rimosse le righe pubbliche `Modifiche locali in attesa` dalla card account/sync e dalla card `Stato database locale`; rimosso anche il box finale `Suggerimento`.
- Android Options: card account e sync automatica fuse in una sola card compatta; rimossa la card separata `Sincronizzazione automatica`, rimossa la testata ridondante della card unificata nello stato signed-in, email mascherata (`x***@gmail.com`), azione `Esci` compatta, nessuna riga pubblica `Cambios locales pendientes` / `Cuenta cloud`.
- Pending locali e account state restano disponibili internamente per runtime/test/harness/evidence; nessuna modifica a Supabase schema, auth flow o core sync.

## Handoff post-fix
Reviewer deve verificare soprattutto:
- iOS recovery con pending locali attivi: `replaceLocalCatalogWithRemoteSnapshot` continua a proteggere pending non classificabili; il follow-up UI field-by-field resta necessario per conflitti reali.
- Android pull-only reconcile su foreground/network/auth e' guardato da `BOOTSTRAP_RETRY_GUARD_MS`, ma puo' comunque essere costoso su cataloghi grandi.
- Live runtime simulator/emulator e' ora eseguito con evidence corrente: iOS->Android PASS, Android->iOS PASS, ProductPrice append-only PASS, History/session PASS, clean reopen/no false push PASS, Options iOS/Android pulite, counts finali coerenti. TASK resta ACTIVE / REVIEW per policy: Codex non marca DONE.

## Evidence
Evidence root:
`docs/TASKS/EVIDENCE/TASK-135-live-simulator-proof-20260617-184019/`

Check eseguiti:
- iOS targeted tests: PASS, 39 tests / 0 failures.
- iOS Debug build: PASS.
- Android targeted tests: PASS.
- Android assembleDebug + lintDebug: PASS.
- iOS git diff check: PASS.
- Android git diff check: PASS.
- service_role/bypass scan: PASS_WITH_NOTE, solo guard di rifiuto in `SupabaseConfig.swift`.
- iOS Options stale cloud-check targeted tests: PASS.
- iOS build/test after Options fix: PASS.
- Android `DefaultInventoryRepositoryTest` targeted backfill cleanup: PASS.
- Android assembleDebug + assembleDebugAndroidTest after backfill cleanup: PASS.
- Live mutation near-realtime matrix: PASS; ProductPrice targeted price ids iOS->Android 13 / Android->iOS 9; History targeted session ids 5 each direction; no full pull.
- Canonical catalog iOS -> Supabase -> Android single prefix `TASK135_IOS_CROSS_20260617_193032_`: PASS.
- Canonical catalog Android -> Supabase -> iOS single prefix `TASK135_ANDROID_CROSS_20260617_193207_`: PASS.
- Clean reopen/no false push: PASS; `sync_events` before/after count `1848`, max id `3100`.
- Final active/user-visible counts parity: Supabase/iOS/Android `products=19704`, `suppliers=66`, `categories=35`, `product_prices=41131`, `history_sessions=39`.
- iOS Options screenshot: PASS; no `Local database needs a cloud check`, pending 0, local DB up to date.
- Android Options screenshot: PASS; no `Waiting to sync`, pending 0, local DB ready.
- Final iOS Debug build after evidence: PASS (`raw/ios-final-debug-build-after-clean-reopen.log`).
- Final iOS Options targeted tests after evidence: PASS, 10 tests / 0 failures (`raw/ios-final-options-tests-after-clean-reopen.log`).
- Final Android targeted backfill cleanup test: PASS (`raw/android-final-backfill-cleanup-targeted-test.log`).
- Final tooling syntax + iOS/Android `git diff --check`: PASS.
- Final forbidden copy scan: PASS (`raw/final-forbidden-copy-scan.txt` empty after headings).
- Post-label localization `plutil -lint`: PASS (`raw/ios-localizations-plutil-after-last-sync-label.log`).
- Post-label iOS Debug build: PASS (`raw/ios-debug-build-after-last-sync-label.log`).
- Post-label iOS Options screenshot/runtime snapshot: PASS (`screenshots/ios-options-last-sync-label-final.jpg`, `raw/ios-options-last-sync-label-runtime-snapshot.txt`).
- Post-label clean reopen invariant: PASS; `sync_events` remains count `1848`, max id `3100` (`counts/sync-events-after-last-sync-label.json`).
- Post-label counts parity: PASS; final active/user-visible counts unchanged and iOS/Android pending aggregate 0 (`counts/final-after-last-sync-label-*.json`).
- Public UX polish tests/builds: PASS; iOS `plutil -lint`, iOS Options targeted tests 9/9, iOS Debug build, Android `CatalogSyncViewModelTest` + `OptionsScreenPublicUxTest`, Android `assembleDebug`, iOS/Android `git diff --check`.
- Final iOS public UX screenshot: PASS; `screenshots/ios-options-final-no-tip-public-ux-20260617-2042.jpg` shows no `Suggerimento`, no public pending row, `Ultima sincronizzazione`, clean local DB counts.
- Final Android public UX screenshot: PASS; `screenshots/android-options-final-unified-no-header-20260617-2044.png` shows one compact account/sync card with no redundant header, masked email, no public pending/account implementation rows, no `Waiting to sync`.
- Final post-polish counts parity: PASS; `counts/final-after-unified-no-header-*.json` all report products `19704`, suppliers `66`, categories `35`, product_prices `41131`, history_sessions `39`; iOS/Android pending aggregate 0.
- Final post-polish clean reopen/no false push invariant: PASS; `counts/sync-events-after-unified-no-header.json` remains count `1848`, max id `3100`.

Check non eseguiti:
- Nessun physical device in questo giro: NON ESEGUITO, fuori dallo scope richiesto per TASK-135 corrente.

## Rischi rimasti
- DONE non marcato per policy locale: serve accettazione/review utente o Claude.
- La UI completa `SyncResolutionPrompt` field-by-field resta follow-up se i conflitti reali devono essere presentati in un nuovo sheet dedicato invece delle superfici TASK-126 esistenti.
- Android `PriceBackfillWorker` resta legacy; ora e' guardato per prodotti cloud-linked, ma una revisione futura potrebbe rimuovere definitivamente il backfill one-shot o legarlo solo a import locali storici.
