# TASK-110 — Test Matrix

Checkpoint: 2026-05-15 12:15 -0400.

| Check | Stato | Evidenza |
|---|---|---|
| iOS GitHub latest read before patch | ✅ ESEGUITO | `git fetch origin main`; `origin/main` = `d4a0f89` locale |
| iOS git status | ✅ ESEGUITO | dirty preesistente + branch TASK-110 |
| Android git status | ✅ ESEGUITO | clean |
| Supabase git status | ⚠️ NON ESEGUIBILE | directory Supabase locale non è un repository git |
| Supabase counts | ✅ ESEGUITO | `supabase-counts-redacted.md` |
| Android Room counts | ✅ ESEGUITO | `android-local-counts.md` |
| iOS SwiftData counts | ✅ ESEGUITO | `ios-local-counts.md` |
| Supabase schema/grants/RLS audit | ✅ ESEGUITO | `schema-audit.md`, `supabase-access-matrix.md` |
| Data API anon 42501 smoke | ✅ ESEGUITO | `supabase-42501-audit.md` |
| Android build | ✅ ESEGUITO | `./gradlew assembleDebug` PASS |
| iOS build | ✅ ESEGUITO | `xcodebuild build ... CODE_SIGNING_ALLOWED=NO` PASS |
| Android targeted tests | ✅ ESEGUITO | `DefaultInventoryRepositoryTest` PASS; `HistorySessionPushCoordinatorTest` PASS isolato con `GRADLE_OPTS='-Djdk.attach.allowAttachSelf=true'` |
| Android combined targeted tests | ⚠️ NON ESEGUIBILE | combined run fallisce per `MockK`/JVM attach `AttachNotSupportedException` dopo Robolectric; codice e test coordinator passano isolati |
| iOS targeted tests | ✅ ESEGUITO | `HistorySessionSyncServiceTests` PASS 8/0 con `-parallel-testing-enabled NO` |
| Android full `./gradlew test` | ❌ NON ESEGUITO | il combined targeted run già dimostra blocker MockK attach; comando full avrebbe lo stesso ostacolo ambientale |
| iOS full test suite | ❌ NON ESEGUITO | eseguiti test mirati History; full suite non lanciata per tempo/rumore device passcode |
| Cross-platform manual create/update/delete | ⚠️ NON ESEGUIBILE | richiede app runtime autenticato su entrambi i client e migration tombstone applicata per delete |
| ProductPrice 40k+ performance | ⚠️ NON ESEGUIBILE | ProductPrice drift diagnosticato ma pipeline non patchata in questa execution |
| Supabase migration apply | ⚠️ NON ESEGUIBILE | migration ledger locale/remoto divergente; migration TASK-110 proposta e file locale creato ma non applicato |
