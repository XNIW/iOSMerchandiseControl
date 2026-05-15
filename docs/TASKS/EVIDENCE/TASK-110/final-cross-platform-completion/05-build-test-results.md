# TASK-110 final cross-platform completion - 05 build/test results

Data: 2026-05-15  
Verdict: **PASS**, con Android full unit suite **PASS_WITH_NOTES** per blocker locale MockK/ByteBuddy.

## iOS

### Build / list

- `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: **PASS**, scheme principale `iOSMerchandiseControl`.
- XcodeBuildMCP `build_run_sim CODE_SIGNING_ALLOWED=NO`: **PASS**, diagnostics finali senza warning/errori sui file patchati.
- Build log finale: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_run_sim_2026-05-15T22-49-53-875Z_pid40283_8f224cc6.log`.

### XCTest mirati TASK-110

Suite principale mirata:

```text
36 tests, 0 failures, 133.955 seconds
```

Copertura inclusa:

- `HistorySessionSyncServiceTests` - tombstone, dirty-local protection, empty grid/offline row.
- `SupabasePullPreviewDiffEngineTests` - metadata-only remote diff e stock-only remote diff non aprono review falsa.
- `SupabaseManualSyncViewModelTests` - direct sync path.
- `SupabaseProductPriceApplyServiceTests/testPagedFullPullAppliesLargeProductPriceHistoryWithoutFixedTotalLimit`.
- `SupabaseProductPriceManualPushServiceTests` - ProductPrice mirror su `inventory_products`.
- `SupabasePullApplyServiceTests/testStockIsIgnoredByDefaultWhenApplyStockQuantityIsFalse`.

Suite regressione/localizzazioni aggiuntiva:

```text
4 tests, 0 failures, 20.394 seconds
```

Copertura inclusa:

- benchmark ProductPrice current/previous medio.
- manual sync cancel/retry benchmark.
- localization keys Release UI.
- localization keys ProductPrice preview.

### Localizzazioni

`plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings`: **PASS** su EN/IT/ES/ZH.

## Android

### Build

- `./gradlew :app:assembleDebug`: **PASS**.

### Test mirati

Comandi seriali finali:

```text
JAVA_TOOL_OPTIONS='-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading' ./gradlew :app:testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest'
```

Esito: **PASS**.

```text
./gradlew :app:testDebugUnitTest --tests DefaultInventoryRepositoryTest --tests AppDatabaseMigrationTest --tests CatalogAutoSyncCoordinatorTest
```

Esito: **PASS**.

Copertura:

- History tombstone push/pull.
- Dirty-local tombstone protection.
- Room migration schema 17.
- Product/catalog bridge e idempotency.
- Auth bootstrap/coordinator behavior.
- Sync status remote-apply e push ack.

### Full unit suite

`JAVA_TOOL_OPTIONS='-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading' ./gradlew test`: **PASS_WITH_NOTES**.

La suite ampia locale fallisce per eccezioni MockK/ByteBuddy attach nel JVM runner (`ByteBuddyAgent` / `AttachNotSupportedException`), non per assert TASK-110 dopo i rerun mirati seriali. Ho provato:

- run senza flag: fallisce per attach.
- run con `-Djdk.attach.allowAttachSelf=true`.
- run con `-XX:+EnableDynamicAgentLoading`.
- separazione test mirati Robolectric/non-Robolectric.

I test TASK-110 rilevanti sono passati serialmente.

Nota esecuzione: un run Gradle parallelo ha prodotto `NoSuchFileException ... in-progress-results...`; rerun seriale PASS. Classificazione: artifact di esecuzione concorrente, non bug app.

## Supabase

- `supabase migration list --linked`: **PASS**, ledger coerente fino a `20260515161500`.
- Authenticated smoke owner-scoped CRUD/tombstone: **PASS**.
- Anon negative Data API: **PASS**, `401/42501`.
- ProductPrice integrity: **PASS**, orphans `0`, duplicates `0`, owner mismatch `0`.
- Final count query seriale: **PASS**.

## Check obbligatori

| Check | Stato | Evidenza |
|-------|-------|----------|
| Build iOS compila | ✅ ESEGUITO | XcodeBuildMCP build/run PASS |
| Build Android compila | ✅ ESEGUITO | `:app:assembleDebug` PASS |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | build finali mirate senza warning nuovi sui file patchati; warning tooling/preesistenti separati |
| Modifiche coerenti con planning | ✅ ESEGUITO | fix limitati a TASK-110 sync/auth/tombstone/ProductPrice/UI state |
| Criteri di accettazione verificati | ✅ ESEGUITO | P8 live + test mirati + smoke Supabase PASS |

