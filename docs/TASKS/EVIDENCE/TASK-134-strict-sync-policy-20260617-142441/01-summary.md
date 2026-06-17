# TASK-134 Summary

## Stato

ACTIVE / REVIEW, non DONE.

TASK-134 e' stato eseguito come override utente sopra TASK-132. La parte implementabile senza un nuovo harness runtime strict e' PASS; i fixture live cross-platform richiesti per field-merge/price-conflict/dirty-protected restano NON ESEGUITI per harness dedicato assente.

## Modifiche

- Aggiunto `docs/SYNC_POLICY.md` come policy operativa comune iOS/Android/Supabase.
- iOS: `CatalogPushService` usa `changedFields` per inviare PATCH prodotto parziali; `deletedAt` e' limitato a `tombstone`.
- iOS: aggiunto test `testTask134CatalogUpdatePayloadOnlyIncludesChangedFields`.
- Android: aggiunta maschera locale `localChangedFields` su `product_remote_refs`, migration Room 17->18 e query candidate aggiornata.
- Android: aggiunto `InventoryProductPatch`, `CatalogRemoteDataSource.patchProduct` e implementazione Supabase update filtrata per `id` + `owner_user_id`.
- Android: `DefaultInventoryRepository` usa PATCH prodotto per righe gia' sincronizzate con maschera affidabile; fallback full-row resta per create/legacy.
- Android: aggiunto test `134 product name update pushes patch only and preserves remote prices`.

## Check

- ✅ ESEGUITO — Supabase final counts/residue: PASS, active `19695/59/28/41109`, history active `35`, `sync_events_total 1823/max 3035`, TASK133/TASK134 residue `0` (`raw/task134-supabase-counts-final.exit = 0`).
- ✅ ESEGUITO — iOS local preflight counts: PASS, active `19695/59/28/41109`, history active `35`, pending/outbox `0/0`, TASK134 residue `0` (`raw/task134-ios-counts.exit = 0`).
- ✅ ESEGUITO — Android local preflight counts: PASS, active `19695/59/28/41109`, history active `35`, outbox/pending refs/tombstones `0`, TASK134 residue `0` (`raw/task134-android-counts.exit = 0`).
- ✅ ESEGUITO — iOS TASK-134 field-mask XCTest: PASS (`raw/ios-task134-field-mask-test.exit = 0`).
- ✅ ESEGUITO — Android TASK-134 patch-only unit test: PASS (`raw/android-task134-patch-only-test.exit = 0`).
- ✅ ESEGUITO — iOS Debug Simulator build: PASS (`raw/ios-debug-build-task134-final.exit = 0`).
- ✅ ESEGUITO — Android `assembleDebug lintDebug`: PASS (`raw/android-assemble-lint-task134-final.exit = 0`).
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: Android lint/test non riportano warning; iOS build riporta warning Swift 6 actor-isolation in file gia' toccati dal blocco TASK-132/133, senza baseline pulita TASK-134-only per classificarli come nuovi o preesistenti.
- ✅ ESEGUITO — iOS `git diff --check`: PASS (`raw/ios-git-diff-check-task134-final.exit = 0`).
- ✅ ESEGUITO — Android `git diff --check`: PASS (`raw/android-git-diff-check-task134-final.exit = 0`).
- ❌ NON ESEGUITO — strict live field merge Android `productName` + iOS `retailPrice` stesso barcode: harness runtime dedicato non presente.
- ❌ NON ESEGUITO — strict live field merge Android `category` + iOS `purchasePrice`: harness runtime dedicato non presente.
- ❌ NON ESEGUITO — strict live price append-only T1/T2 + same-effectiveAt conflict: coperto da test/policy locale, non da fixture live.
- ❌ NON ESEGUITO — dirty/protected reopen no-push con fixture unsafe iniettata: clean no-push storico PASS, fixture dirty TASK-134 non eseguita.

## Rischi

- Non dichiarare TASK-134 DONE finche' i fixture strict live cross-platform non vengono implementati/eseguiti o esplicitamente accettati come non richiesti.
- Android watermark locale preflight resta superiore al max cloud per eventi benchmark TASK-133 cancellati; diagnostico, non user-visible.
- La policy strict field-merge e' ora coperta da patch code/test su iOS e Android, ma non da prova runtime due-device simultanea.
